-- Create Views for Reporting and Analytics
-- These views provide commonly used data aggregations

USE [SampleDW];
GO

-- Drop views if they exist
IF OBJECT_ID('[dbo].[vw_OrderSummary]', 'V') IS NOT NULL DROP VIEW [dbo].[vw_OrderSummary];
IF OBJECT_ID('[dbo].[vw_CustomerOrders]', 'V') IS NOT NULL DROP VIEW [dbo].[vw_CustomerOrders];
IF OBJECT_ID('[dbo].[vw_ProductSales]', 'V') IS NOT NULL DROP VIEW [dbo].[vw_ProductSales];
GO

-- Order Summary View
CREATE VIEW [dbo].[vw_OrderSummary]
AS
SELECT 
    o.OrderID,
    o.OrderDate,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.Email AS CustomerEmail,
    c.City AS CustomerCity,
    p.ProductName,
    p.Category,
    o.Quantity,
    p.Price AS UnitPrice,
    o.TotalAmount,
    o.Status
FROM [dbo].[Orders] o
INNER JOIN [dbo].[Customers] c ON o.CustomerID = c.CustomerID
INNER JOIN [dbo].[Products] p ON o.ProductID = p.ProductID;
GO

-- Customer Orders View
CREATE VIEW [dbo].[vw_CustomerOrders]
AS
SELECT 
    c.CustomerID,
    c.FirstName + ' ' + c.LastName AS CustomerName,
    c.Email,
    c.City,
    c.Country,
    COUNT(o.OrderID) AS TotalOrders,
    SUM(o.TotalAmount) AS TotalSpent,
    AVG(o.TotalAmount) AS AverageOrderValue,
    MAX(o.OrderDate) AS LastOrderDate
FROM [dbo].[Customers] c
LEFT JOIN [dbo].[Orders] o ON c.CustomerID = o.CustomerID
GROUP BY 
    c.CustomerID,
    c.FirstName,
    c.LastName,
    c.Email,
    c.City,
    c.Country;
GO

-- Product Sales View
CREATE VIEW [dbo].[vw_ProductSales]
AS
SELECT 
    p.ProductID,
    p.ProductName,
    p.Category,
    p.Price,
    p.Stock,
    COUNT(o.OrderID) AS TimesSold,
    SUM(o.Quantity) AS TotalQuantitySold,
    SUM(o.TotalAmount) AS TotalRevenue
FROM [dbo].[Products] p
LEFT JOIN [dbo].[Orders] o ON p.ProductID = o.ProductID
GROUP BY 
    p.ProductID,
    p.ProductName,
    p.Category,
    p.Price,
    p.Stock;
GO

PRINT 'Views created successfully!';
PRINT '';
PRINT 'Available views:';
PRINT '  - vw_OrderSummary: Complete order details with customer and product information';
PRINT '  - vw_CustomerOrders: Customer aggregations with order statistics';
PRINT '  - vw_ProductSales: Product sales performance metrics';
GO
