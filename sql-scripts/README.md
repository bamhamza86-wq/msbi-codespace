# SQL Scripts for MSBI Environment

This directory contains SQL scripts for setting up and managing the MSBI data warehouse environment.

## Scripts Overview

### Setup Scripts (Run in Order)

1. **create-tables.sql**
   - Creates the main data warehouse tables
   - Tables: Customers, Products, Orders
   - Includes proper foreign keys and indexes

2. **load-sample-data.sql**
   - Loads sample data into the tables
   - 10 customers, 10 products, 10 orders
   - Includes verification queries

3. **create-views.sql**
   - Creates reporting views
   - vw_OrderSummary: Complete order details
   - vw_CustomerOrders: Customer statistics
   - vw_ProductSales: Product performance

4. **create-stored-procedures.sql**
   - Creates stored procedures for data operations
   - sp_RefreshStagingData: ETL staging refresh
   - sp_GetSalesByDateRange: Sales reporting
   - sp_GetTopCustomers: Customer analytics

5. **setup-complete.sql**
   - Master script that runs all setup scripts in order
   - Single command to set up everything

## Usage

### Quick Setup (All-in-One)

**Note:** The setup-complete.sql script uses `:r` commands which require running from the sql-scripts directory.

```bash
cd /workspaces/msbi-codespace/sql-scripts
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i setup-complete.sql -C
```

**Alternative:** Run individual scripts from the workspace root (see below).

### Individual Scripts

Run scripts individually if you need more control:

```bash
# 1. Create tables
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/create-tables.sql -C

# 2. Load data
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/load-sample-data.sql -C

# 3. Create views
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/create-views.sql -C

# 4. Create stored procedures
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/create-stored-procedures.sql -C
```

## Testing the Setup

After running the setup scripts, test with these queries:

```sql
-- View all orders with details
SELECT * FROM [dbo].[vw_OrderSummary];

-- Get customer statistics
SELECT * FROM [dbo].[vw_CustomerOrders] ORDER BY TotalSpent DESC;

-- Check product sales
SELECT * FROM [dbo].[vw_ProductSales] ORDER BY TotalRevenue DESC;

-- Get top 5 customers
EXEC [dbo].[sp_GetTopCustomers] @TopN = 5;

-- Get sales for January 2024
EXEC [dbo].[sp_GetSalesByDateRange] @StartDate = '2024-01-01', @EndDate = '2024-01-31';
```

## PowerShell Usage

You can also use PowerShell to execute these scripts:

```powershell
# Source the management tool
. ./manage-msbi.ps1

# Execute setup
Invoke-Sqlcmd -ServerInstance "localhost" -Database "SampleDW" -InputFile "sql-scripts/setup-complete.sql" -Username "sa" -Password "Passw0rd123!" -TrustServerCertificate
```

## Database Schema

```
SampleDW (Database)
├── dbo (Schema)
│   ├── Customers (Table)
│   ├── Products (Table)
│   ├── Orders (Table)
│   ├── vw_OrderSummary (View)
│   ├── vw_CustomerOrders (View)
│   ├── vw_ProductSales (View)
│   ├── sp_RefreshStagingData (Procedure)
│   ├── sp_GetSalesByDateRange (Procedure)
│   └── sp_GetTopCustomers (Procedure)
└── ETL (Schema)
    └── StagingCustomer (Table)
```

## Notes

- All scripts are idempotent (can be run multiple times safely)
- Tables are dropped and recreated to ensure clean state
- Sample data is French-themed for demonstration purposes
- Scripts use proper error handling and transactions where appropriate
