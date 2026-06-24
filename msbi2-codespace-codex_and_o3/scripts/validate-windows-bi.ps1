param(
    [Parameter(Mandatory = $true)][string]$SqlServer,
    [Parameter(Mandatory = $true)][string]$SqlUser,
    [Parameter(Mandatory = $true)][string]$SqlPassword,
    [string]$SsasServer = "localhost",
    [string]$SsasDatabase = "DW_Tabular",
    [string]$SsrsBaseUrl = "http://localhost/ReportServer",
    [string]$SsrsFolder = "/MSBI2",
    [string]$SsisPackagePath = "",
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot),
    [System.Management.Automation.PSCredential]$SsrsCredential,
    [switch]$SkipSsisExecution
)

$ErrorActionPreference = "Stop"

function Invoke-DwScalar {
    param([Parameter(Mandatory = $true)][string]$Query)

    $connectionString = "Server=$SqlServer;Database=DW;User Id=$SqlUser;Password=$SqlPassword;TrustServerCertificate=True;"
    $connection = [System.Data.SqlClient.SqlConnection]::new($connectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        return $command.ExecuteScalar()
    }
    finally {
        if ($null -ne $connection) {
            $connection.Dispose()
        }
    }
}

function Assert-DwLoaded {
    $factRows = [int64](Invoke-DwScalar "SELECT COUNT_BIG(*) FROM dw.FactSales;")
    $salesTotal = [decimal](Invoke-DwScalar "SELECT CAST(SUM(SalesAmount) AS decimal(18,2)) FROM dw.FactSales;")
    $westSales = [decimal](Invoke-DwScalar "SELECT CAST(SUM(SalesAmount) AS decimal(18,2)) FROM rpt.vSalesByRegion WHERE RegionCode = 'WEST';")

    if ($factRows -ne 6) {
        throw "Expected 6 fact rows in DW, found $factRows."
    }
    if ([Math]::Abs($salesTotal - [decimal]8260.00) -gt [decimal]0.01) {
        throw "Expected DW sales total 8260.00, found $salesTotal."
    }
    if ([Math]::Abs($westSales - [decimal]450.00) -gt [decimal]0.01) {
        throw "Expected WEST sales 450.00 after delta load, found $westSales."
    }

    Write-Host "DW SQL validation OK: $factRows fact rows, total $salesTotal, WEST $westSales."
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

    $defaultPackages = @(
        (Join-Path $ProjectRoot "ssis\LoadDWDelta.dtsx"),
        (Join-Path $ProjectRoot "ssis\bin\LoadDWDelta.dtsx")
    )
    foreach ($package in $defaultPackages) {
        if (Test-Path -LiteralPath $package) {
            return (Resolve-Path -LiteralPath $package).Path
        }
    }

    throw "No compiled SSIS package was found. Generate ssis\LoadDWDelta.dtsx from ssis\LoadDWDelta.biml or pass -SsisPackagePath."
}

function Assert-SsisDeltaPackage {
    if ($SkipSsisExecution) {
        Write-Warning "Skipping SSIS execution because -SkipSsisExecution was specified."
        return
    }

    $dtexec = Find-Dtexec
    if (-not $dtexec) {
        throw "dtexec.exe was not found. Install SQL Server Integration Services runtime on this Windows host."
    }

    $package = Resolve-SsisPackage
    $process = Start-Process -FilePath $dtexec -ArgumentList @("/F", $package, "/REP", "E") -Wait -NoNewWindow -PassThru
    if ($process.ExitCode -ne 0) {
        throw "SSIS package failed through dtexec.exe with exit code $($process.ExitCode)."
    }

    Write-Host "SSIS delta package validation OK: $package"
}

function Assert-SsasModel {
    if (-not (Get-Module -ListAvailable -Name SqlServer)) {
        throw "SqlServer PowerShell module was not found. Install-Module SqlServer is required for Invoke-ASCmd."
    }

    Import-Module SqlServer -ErrorAction Stop
    $dax = @"
EVALUATE
ROW(
  "FactRows", COUNTROWS('Fact Sales'),
  "TotalSales", [Total Sales]
)
"@

    $result = Invoke-ASCmd -Server $SsasServer -Database $SsasDatabase -Query $dax
    if ([string]::IsNullOrWhiteSpace([string]$result)) {
        throw "SSAS returned an empty result for the tabular model validation query."
    }

    Write-Host "SSAS tabular validation OK on $SsasServer/$SsasDatabase."
}

function Assert-SsrsReport {
    param([Parameter(Mandatory = $true)][string]$ReportName)

    $reportPath = "$($SsrsFolder.TrimEnd('/'))/$ReportName"
    if (-not $reportPath.StartsWith("/")) {
        $reportPath = "/$reportPath"
    }

    $url = "$($SsrsBaseUrl.TrimEnd('/'))?$reportPath&rs:Command=Render&rs:Format=PDF"
    $outFile = Join-Path $env:TEMP "$ReportName-msbi2-validation.pdf"
    $request = @{
        Uri = $url
        OutFile = $outFile
        ErrorAction = "Stop"
    }
    if ($SsrsCredential) {
        $request.Credential = $SsrsCredential
    }
    else {
        $request.UseDefaultCredentials = $true
    }

    Invoke-WebRequest @request | Out-Null
    $length = (Get-Item -LiteralPath $outFile).Length
    if ($length -lt 1024) {
        throw "SSRS rendered $ReportName, but the PDF output is unexpectedly small: $length bytes."
    }

    Write-Host "SSRS report validation OK: $ReportName ($length bytes)."
}

Assert-DwLoaded
Assert-SsisDeltaPackage
Assert-DwLoaded
Assert-SsasModel
Assert-SsrsReport -ReportName "SalesByRegion"

Write-Host "MSBI2 Windows BI validation complete."
