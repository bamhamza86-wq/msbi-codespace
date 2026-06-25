# MSBI PowerShell Management Tool
# Usage: . ./manage-msbi.ps1

$sqlServer = "localhost"
$sqlUser = "sa"
$sqlPassword = "Passw0rd123!"

function Test-SqlConnection {
    Write-Host "Testing SQL Server Connection..." -ForegroundColor Cyan

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = "Server=$sqlServer;User Id=$sqlUser;Password=$sqlPassword;TrustServerCertificate=True;"
        $connection.Open()

        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT @@VERSION"
        $version = $command.ExecuteScalar()

        Write-Host "✅ SQL Server Connected!" -ForegroundColor Green
        Write-Host "Version: $version" -ForegroundColor Gray

        $connection.Close()
        return $true
    }
    catch {
        Write-Host "❌ Connection Failed: $_" -ForegroundColor Red
        return $false
    }
}

function Get-Databases {
    Write-Host "Listing SQL Server Databases..." -ForegroundColor Cyan

    try {
        $connectionString = "Server=$sqlServer;User Id=$sqlUser;Password=$sqlPassword;TrustServerCertificate=True;"
        $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
        $connection.Open()

        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT name, create_date FROM sys.databases ORDER BY name"
        $reader = $command.ExecuteReader()

        Write-Host ""
        while ($reader.Read()) {
            $name = $reader["name"]
            $created = $reader["create_date"]
            Write-Host "  • $name (Created: $created)" -ForegroundColor Yellow
        }
        Write-Host ""

        $reader.Close()
        $connection.Close()
    }
    catch {
        Write-Host "❌ Error: $_" -ForegroundColor Red
    }
}

function Invoke-SqlQuery {
    param(
        [string]$Query,
        [string]$Database = "master"
    )

    Write-Host "Executing query on $Database..." -ForegroundColor Cyan

    try {
        $connectionString = "Server=$sqlServer;Database=$Database;User Id=$sqlUser;Password=$sqlPassword;TrustServerCertificate=True;"
        $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
        $connection.Open()

        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        $result = $command.ExecuteScalar()

        Write-Host "Result: $result" -ForegroundColor Green

        $connection.Close()
    }
    catch {
        Write-Host "❌ Error: $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "MSBI PowerShell Management Tool" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available commands:" -ForegroundColor Yellow
Write-Host "  Test-SqlConnection              - Test SQL Server connection" -ForegroundColor Gray
Write-Host "  Get-Databases                   - List all databases" -ForegroundColor Gray
Write-Host "  Invoke-SqlQuery -Query '...'    - Execute SQL query" -ForegroundColor Gray
Write-Host ""
