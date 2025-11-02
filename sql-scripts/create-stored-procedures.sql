-- Create Stored Procedures for Data Operations
-- These procedures support ETL and data management tasks

USE [SampleDW];
GO

-- Drop procedures if they exist
IF OBJECT_ID('[dbo].[sp_RefreshStagingData]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[sp_RefreshStagingData];
IF OBJECT_ID('[dbo].[sp_GetSalesByDateRange]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[sp_GetSalesByDateRange];
IF OBJECT_ID('[dbo].[sp_GetTopCustomers]', 'P') IS NOT NULL DROP PROCEDURE [dbo].[sp_GetTopCustomers];
GO

-- Procedure to refresh staging data
CREATE PROCEDURE [dbo].[sp_RefreshStagingData]
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Clear staging table
        TRUNCATE TABLE [ETL].[StagingCustomer];
        
        -- Load current customer data into staging
        INSERT INTO [ETL].[StagingCustomer] (CustomerID, FirstName, LastName, Email)
        SELECT CustomerID, FirstName, LastName, Email
        FROM [dbo].[Customers];
        
        COMMIT TRANSACTION;
        
        PRINT 'Staging data refreshed successfully!';
        PRINT CAST(@@ROWCOUNT AS VARCHAR(10)) + ' records loaded.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        PRINT 'Error refreshing staging data: ' + ERROR_MESSAGE();
    END CATCH
END;
GO

-- Procedure to get sales by date range
CREATE PROCEDURE [dbo].[sp_GetSalesByDateRange]
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        CONVERT(DATE, OrderDate) AS SaleDate,
        COUNT(OrderID) AS OrderCount,
        SUM(TotalAmount) AS TotalSales,
        AVG(TotalAmount) AS AverageSale
    FROM [dbo].[Orders]
    WHERE OrderDate BETWEEN @StartDate AND @EndDate
    GROUP BY CONVERT(DATE, OrderDate)
    ORDER BY SaleDate;
END;
GO

-- Procedure to get top customers by spending
CREATE PROCEDURE [dbo].[sp_GetTopCustomers]
    @TopN INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT TOP (@TopN)
        c.CustomerID,
        c.FirstName + ' ' + c.LastName AS CustomerName,
        c.Email,
        c.City,
        COUNT(o.OrderID) AS TotalOrders,
        SUM(o.TotalAmount) AS TotalSpent
    FROM [dbo].[Customers] c
    INNER JOIN [dbo].[Orders] o ON c.CustomerID = o.CustomerID
    GROUP BY 
        c.CustomerID,
        c.FirstName,
        c.LastName,
        c.Email,
        c.City
    ORDER BY TotalSpent DESC;
END;
GO

PRINT 'Stored procedures created successfully!';
PRINT '';
PRINT 'Available procedures:';
PRINT '  - sp_RefreshStagingData: Refresh ETL staging table with current data';
PRINT '  - sp_GetSalesByDateRange @StartDate, @EndDate: Get sales aggregated by date';
PRINT '  - sp_GetTopCustomers @TopN: Get top N customers by spending';
GO
