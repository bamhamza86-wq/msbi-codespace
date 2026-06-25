param(
    [Parameter(Mandatory = $true)][string]$SqlServer,
    [Parameter(Mandatory = $true)][string]$SqlUser,
    [Parameter(Mandatory = $true)][string]$SqlPassword,
    [string]$SsasServer = "localhost",
    [string]$SsrsBaseUrl = "http://localhost/ReportServer",
    [string]$SsasDatabase = "DW_Tabular",
    [string]$SsisPackagePath = "",
    [string]$SsisConnectionManagerName = "DW",
    [string]$ProjectRoot = "",
    [switch]$SkipSsisExecution
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptRoot = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $PSScriptRoot
    }
    else {
        Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    $ProjectRoot = Split-Path -Parent $scriptRoot
}
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

function Test-SqlDw {
    $connectionString = "Server=$SqlServer;Database=DW;User Id=$SqlUser;Password=$SqlPassword;TrustServerCertificate=True;"
    $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = "SELECT COUNT(*) FROM dw.FactSales"
    $rows = [int]$command.ExecuteScalar()
    $connection.Close()
    if ($rows -lt 1) {
        throw "DW.dbo.FactSales is empty or unavailable."
    }
    Write-Host "DW SQL validation OK: $rows fact rows."
}

function Find-Dtexec {
    $command = Get-Command dtexec.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Recurse -Filter dtexec.exe -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if ($candidates) {
        return $candidates.FullName
    }

    return $null
}

function Resolve-SsisPackage {
    if (-not [string]::IsNullOrWhiteSpace($SsisPackagePath)) {
        if (-not (Test-Path -LiteralPath $SsisPackagePath)) {
            throw "SSIS package was provided but not found: $SsisPackagePath"
        }
        return (Resolve-Path -LiteralPath $SsisPackagePath).Path
    }

    $defaultPackage = Join-Path $ProjectRoot "ssis\LoadDWDelta.dtsx"
    if (Test-Path -LiteralPath $defaultPackage) {
        return (Resolve-Path -LiteralPath $defaultPackage).Path
    }

    throw "SSIS package not found. Expected ssis\LoadDWDelta.dtsx or pass -SsisPackagePath."
}

function Get-SsisConnectionString {
    return "Provider=MSOLEDBSQL;Data Source=$SqlServer;Initial Catalog=DW;User ID=$SqlUser;Password=$SqlPassword;Trust Server Certificate=True;"
}

function Invoke-SsisDeltaLoad {
    if ($SkipSsisExecution) {
        Write-Warning "Skipping SSIS execution because -SkipSsisExecution was specified."
        return
    }

    $dtexec = Find-Dtexec
    if (-not $dtexec) {
        Write-Warning "dtexec.exe was not found. Skipping SSIS package execution on this host."
        return
    }

    $package = Resolve-SsisPackage
    $ssisConnection = "{0};{1}" -f $SsisConnectionManagerName, (Get-SsisConnectionString)
    & $dtexec /F $package /Connection $ssisConnection /REP E
    if ($LASTEXITCODE -ne 0) {
        throw "SSIS package failed through dtexec.exe with exit code $LASTEXITCODE."
    }

    Write-Host "SSIS delta package executed: $package"
}

function Deploy-SsasModel {
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-Warning "SqlServer PowerShell module not found. Skipping SSAS deploy."
        return
    }
    Import-Module SqlServer -ErrorAction Stop
    $modelPath = Join-Path $ProjectRoot "ssas\model.bim"
    $model = Get-Content $modelPath -Raw | ConvertFrom-Json
    $model.name = $SsasDatabase
    $model.model.dataSources[0].connectionString = "Provider=MSOLEDBSQL;Data Source=$SqlServer;Initial Catalog=DW;User ID=$SqlUser;Password=$SqlPassword;Trust Server Certificate=True;"
    $model.model.dataSources[0] | Add-Member -NotePropertyName "impersonationMode" -NotePropertyValue "impersonateServiceAccount" -Force
    $payload = @{
        createOrReplace = @{
            object = @{ database = $SsasDatabase }
            database = $model
        }
    }
    $temp = Join-Path $env:TEMP "msbi2-deploy-model.tmsl"
    $payload | ConvertTo-Json -Depth 100 | Set-Content -Path $temp -Encoding UTF8
    $deployResult = Invoke-ASCmd -Server $SsasServer -InputFile $temp
    if ($deployResult -match "<Error|<Exception") {
        throw "SSAS model deployment failed: $deployResult"
    }

    $refreshPayload = @{
        refresh = @{
            type = "full"
            objects = @(@{ database = $SsasDatabase })
        }
    }
    $refreshTemp = Join-Path $env:TEMP "msbi2-refresh-model.tmsl"
    $refreshPayload | ConvertTo-Json -Depth 20 | Set-Content -Path $refreshTemp -Encoding UTF8
    $refreshResult = Invoke-ASCmd -Server $SsasServer -InputFile $refreshTemp
    if ($refreshResult -match "<Error|<Exception") {
        throw "SSAS model refresh failed: $refreshResult"
    }

    Write-Host "SSAS model deployed and refreshed on $SsasServer/$SsasDatabase."
}

function Deploy-SsrsReports {
    if (-not (Get-Module -ListAvailable -Name ReportingServicesTools)) {
        Write-Warning "ReportingServicesTools module not found. Skipping SSRS upload."
        return
    }
    Import-Module ReportingServicesTools -ErrorAction Stop
    $folder = "/MSBI2"
    $ssrsSqlServer = if ($SqlServer -match "^(tcp|np|lpc):") { $SqlServer } else { "tcp:$SqlServer" }
    New-RsFolder -ReportServerUri $SsrsBaseUrl -Path "/" -Name "MSBI2" -ErrorAction SilentlyContinue | Out-Null
    Get-ChildItem (Join-Path $ProjectRoot "ssrs") -Filter *.rdl | ForEach-Object {
        Write-RsCatalogItem -ReportServerUri $SsrsBaseUrl -Path $_.FullName -RsFolder $folder -Name $_.BaseName -Overwrite
        $reportPath = "$folder/$($_.BaseName)"
        $dataSources = Get-RsItemDataSource -ReportServerUri $SsrsBaseUrl -RsItem $reportPath
        foreach ($dataSource in $dataSources) {
            $dataSource.Item.ConnectString = "Data Source=$ssrsSqlServer;Initial Catalog=DW;Encrypt=False;TrustServerCertificate=True"
            $dataSource.Item.UseOriginalConnectString = $false
            $dataSource.Item.CredentialRetrieval = "Store"
            $dataSource.Item.Username = $SqlUser
            $dataSource.Item.Password = $SqlPassword
            $dataSource.Item.WindowsCredentials = $false
            $dataSource.Item.ImpersonateUser = $false
        }
        Set-RsItemDataSource -ReportServerUri $SsrsBaseUrl -RsItem $reportPath -DataSource $dataSources
    }
    Write-Host "SSRS reports uploaded to $folder."
}

Invoke-SsisDeltaLoad
Test-SqlDw
Deploy-SsasModel
Deploy-SsrsReports
