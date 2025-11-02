-- Create Data Warehouse Tables
-- This script creates the main tables for the sample data warehouse

USE [SampleDW];
GO

-- Drop tables if they exist (for clean re-creation)
IF OBJECT_ID('[dbo].[Orders]', 'U') IS NOT NULL DROP TABLE [dbo].[Orders];
IF OBJECT_ID('[dbo].[Products]', 'U') IS NOT NULL DROP TABLE [dbo].[Products];
IF OBJECT_ID('[dbo].[Customers]', 'U') IS NOT NULL DROP TABLE [dbo].[Customers];
GO

-- Create Customers dimension table
CREATE TABLE [dbo].[Customers] (
    CustomerID INT PRIMARY KEY,
    FirstName NVARCHAR(100) NOT NULL,
    LastName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    Phone NVARCHAR(20),
    City NVARCHAR(100),
    Country NVARCHAR(100),
    RegistrationDate DATE,
    CreatedDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);
GO

-- Create Products dimension table
CREATE TABLE [dbo].[Products] (
    ProductID INT PRIMARY KEY,
    ProductName NVARCHAR(200) NOT NULL,
    Category NVARCHAR(100),
    Price DECIMAL(10, 2) NOT NULL,
    Stock INT DEFAULT 0,
    SupplierID INT,
    CreatedDate DATETIME DEFAULT GETDATE(),
    ModifiedDate DATETIME DEFAULT GETDATE()
);
GO

-- Create Orders fact table
CREATE TABLE [dbo].[Orders] (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL,
    OrderDate DATE NOT NULL,
    TotalAmount DECIMAL(10, 2) NOT NULL,
    Status NVARCHAR(50),
    CreatedDate DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (CustomerID) REFERENCES [dbo].[Customers](CustomerID),
    FOREIGN KEY (ProductID) REFERENCES [dbo].[Products](ProductID)
);
GO

-- Create indexes for better query performance
CREATE INDEX IX_Orders_CustomerID ON [dbo].[Orders](CustomerID);
CREATE INDEX IX_Orders_ProductID ON [dbo].[Orders](ProductID);
CREATE INDEX IX_Orders_OrderDate ON [dbo].[Orders](OrderDate);
GO

PRINT 'Tables created successfully!';
GO
