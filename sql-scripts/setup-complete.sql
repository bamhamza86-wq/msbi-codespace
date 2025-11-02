-- Complete MSBI Setup Script
-- This script runs all setup steps in the correct order

PRINT '===========================================';
PRINT 'MSBI Complete Setup Script';
PRINT '===========================================';
PRINT '';

-- Step 1: Create Tables
PRINT 'Step 1: Creating tables...';
:r create-tables.sql
PRINT '';

-- Step 2: Load Sample Data
PRINT 'Step 2: Loading sample data...';
:r load-sample-data.sql
PRINT '';

-- Step 3: Create Views
PRINT 'Step 3: Creating views...';
:r create-views.sql
PRINT '';

-- Step 4: Create Stored Procedures
PRINT 'Step 4: Creating stored procedures...';
:r create-stored-procedures.sql
PRINT '';

PRINT '===========================================';
PRINT 'Setup Complete!';
PRINT '===========================================';
PRINT '';
PRINT 'Database: SampleDW';
PRINT 'Tables: Customers, Products, Orders';
PRINT 'Views: vw_OrderSummary, vw_CustomerOrders, vw_ProductSales';
PRINT 'Stored Procedures: sp_RefreshStagingData, sp_GetSalesByDateRange, sp_GetTopCustomers';
PRINT '';
PRINT 'Test query:';
PRINT 'SELECT * FROM [dbo].[vw_OrderSummary];';
GO
