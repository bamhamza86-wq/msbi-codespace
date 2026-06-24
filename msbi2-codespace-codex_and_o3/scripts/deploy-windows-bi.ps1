param(
    [Parameter(Mandatory = $true)][string]$SqlServer,
    [Parameter(Mandatory = $true)][string]$SqlUser,
    [Parameter(Mandatory = $true)][string]$SqlPassword,
    [string]$SsasServer = "localhost",
    [string]$SsrsBaseUrl = "http://localhost/ReportServer",
    [string]$SsasDatabase = "DW_Tabular",
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

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

function Deploy-SsasModel {
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        Write-Warning "SqlServer PowerShell module not found. Skipping SSAS deploy."
        return
    }
    Import-Module SqlServer -ErrorAction Stop
    $modelPath = Join-Path $ProjectRoot "ssas\model.bim"
    $model = Get-Content $modelPath -Raw | ConvertFrom-Json
    $model.name = $SsasDatabase
    $model.model.dataSources[0].connectionString =
        $model.model.dataSources[0].connectionString.Replace("{{SQL_SERVER}}", $SqlServer)
    $payload = @{
        createOrReplace = @{
            object = @{ database = $SsasDatabase }
            database = $model
        }
    }
    $temp = Join-Path $env:TEMP "msbi2-deploy-model.tmsl"
    $payload | ConvertTo-Json -Depth 100 | Set-Content -Path $temp -Encoding UTF8
    Invoke-ASCmd -Server $SsasServer -InputFile $temp
    Write-Host "SSAS model deployment submitted to $SsasServer."
}

function Deploy-SsrsReports {
    if (-not (Get-Module -ListAvailable -Name ReportingServicesTools)) {
        Write-Warning "ReportingServicesTools module not found. Skipping SSRS upload."
        return
    }
    Import-Module ReportingServicesTools -ErrorAction Stop
    $folder = "/MSBI2"
    New-RsFolder -ReportServerUri $SsrsBaseUrl -Path "/" -Name "MSBI2" -ErrorAction SilentlyContinue | Out-Null
    Get-ChildItem (Join-Path $ProjectRoot "ssrs") -Filter *.rdl | ForEach-Object {
        Write-RsCatalogItem -ReportServerUri $SsrsBaseUrl -Path $folder -Destination $_.Name -FilePath $_.FullName -Overwrite
    }
    Write-Host "SSRS reports uploaded to $folder."
}

Test-SqlDw

Write-Host "SSIS delta package source is in ssis\LoadDWDelta.biml."
Write-Host "Generate the package with Biml tooling or map the Execute SQL Task to: EXEC etl.usp_LoadDeltaAll @BatchName = N'ssis-delta';"

Deploy-SsasModel
Deploy-SsrsReports
