# SSIS Packages Directory

This directory is for storing SSIS (SQL Server Integration Services) packages (.dtsx files).

## Overview

SSIS packages are used for ETL (Extract, Transform, Load) operations in the MSBI environment. This directory serves as the central location for all SSIS package development and deployment.

## Package Development

### Creating SSIS Packages

SSIS packages are typically created using:
1. **SQL Server Data Tools (SSDT)** - Windows-based development environment
2. **Visual Studio** with SQL Server Integration Services projects extension

### Alternative: Using dtexec Command-Line

Since SSDT/Visual Studio are not available in Codespaces (Linux), you can:
1. Develop packages locally on Windows with SSDT
2. Upload the .dtsx files to this directory
3. Execute them using the SSIS runtime in the container

## Sample Package Configurations

### Connection Strings

When creating SSIS packages, use these connection strings:

**SQL Server Connection:**
```
Server=localhost,1433;
Database=SampleDW;
User ID=sa;
Password=Passw0rd123!;
TrustServerCertificate=True;
```

**Oracle Connection:**
```
Data Source=localhost:1521/FREEPDB1;
User ID=system;
Password=Oracle_123;
```

## Common SSIS Package Types

### 1. CSV to SQL Server Import
Load data from CSV files in `/data/` directory into SQL Server tables.

**Key Components:**
- Flat File Source (CSV)
- Data Conversion (if needed)
- OLE DB Destination (SQL Server)

### 2. Staging to Production Load
Move data from ETL.StagingCustomer to dbo.Customers.

**Key Components:**
- OLE DB Source (Staging)
- Derived Column (transformations)
- OLE DB Destination (Production)

### 3. SQL Server to Oracle Transfer
Transfer data from SQL Server to Oracle Database.

**Key Components:**
- OLE DB Source (SQL Server)
- Data Conversion
- Oracle Destination

## Package Execution

### Using PowerShell

```powershell
# Note: SSIS runtime may not be fully available in Linux containers
# This is a reference for when packages are deployed to Windows environments

# Execute a package
dtexec /File "ssis-packages/MyPackage.dtsx" /Reporting V

# Execute with connection override
dtexec /File "ssis-packages/MyPackage.dtsx" /Connection "SQL Server";"Data Source=localhost;User ID=sa;Password=Passw0rd123!;"
```

### Using SQL Server Agent (Windows)

1. Deploy package to SSISDB catalog
2. Create SQL Server Agent job
3. Schedule package execution

## SSISDB Catalog

The SSISDB catalog was created during initialization (see init-sql-server.sql). This provides:
- Centralized package storage
- Execution logging
- Parameter management
- Environment configurations

### Deploying to SSISDB

```sql
-- Check if SSISDB exists
SELECT name FROM sys.databases WHERE name = 'SSISDB';

-- View catalog folders
USE SSISDB;
SELECT * FROM catalog.folders;
```

## Best Practices

1. **Version Control**: Keep all .dtsx files in this Git repository
2. **Configuration**: Use project parameters for connection strings
3. **Logging**: Enable SSIS logging for all packages
4. **Error Handling**: Implement proper error handling in packages
5. **Documentation**: Add descriptions to each package and task
6. **Testing**: Test packages with sample data before production

## Package Templates

### Basic CSV Import Template Structure

```
Package: ImportCustomersFromCSV
├── Data Flow Task: Load Customers
│   ├── Flat File Source: customers.csv
│   ├── Data Conversion: Convert data types
│   ├── Derived Column: Add audit fields
│   └── OLE DB Destination: dbo.Customers
└── Execute SQL Task: Log completion
```

### Incremental Load Template

```
Package: IncrementalCustomerLoad
├── Execute SQL Task: Get last load date
├── Data Flow Task: Extract new/changed records
│   ├── OLE DB Source: Query with date filter
│   ├── Lookup: Check for existing records
│   ├── Conditional Split: New vs Updates
│   ├── OLE DB Destination: Insert new
│   └── OLE DB Command: Update existing
└── Execute SQL Task: Update load date
```

## Sample Data Flow

For a working example, see the sample data and SQL scripts in:
- `/data/` - Sample CSV files
- `/sql-scripts/` - Table definitions and sample data loading

## References

- [SSIS Documentation](https://learn.microsoft.com/en-us/sql/integration-services/)
- [SSISDB Catalog](https://learn.microsoft.com/en-us/sql/integration-services/catalog/)
- [dtexec Utility](https://learn.microsoft.com/en-us/sql/integration-services/packages/dtexec-utility)

## Notes

⚠️ **Important**: Full SSIS development requires Windows with SQL Server Data Tools (SSDT). This Codespaces environment provides the runtime and database components. For full package development:
1. Develop packages on Windows with SSDT
2. Store packages in this directory
3. Execute packages in the Codespaces environment for testing

For Linux-native ETL, consider alternatives:
- Python with pandas and pyodbc
- Azure Data Factory
- Apache Airflow
