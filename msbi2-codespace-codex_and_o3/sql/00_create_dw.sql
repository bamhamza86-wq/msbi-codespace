IF DB_ID(N'DW') IS NULL
BEGIN
    CREATE DATABASE [DW];
END
GO

USE [DW];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'source') EXEC(N'CREATE SCHEMA source');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stg') EXEC(N'CREATE SCHEMA stg');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dw') EXEC(N'CREATE SCHEMA dw');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'etl') EXEC(N'CREATE SCHEMA etl');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'rpt') EXEC(N'CREATE SCHEMA rpt');
GO

IF OBJECT_ID(N'source.RegionChanges', N'U') IS NULL
BEGIN
    CREATE TABLE source.RegionChanges
    (
        RegionCode nvarchar(20) NOT NULL,
        RegionName nvarchar(100) NOT NULL,
        LoadBatchId int NOT NULL,
        ModifiedAt datetime2(0) NOT NULL,
        CONSTRAINT PK_SourceRegionChanges PRIMARY KEY (RegionCode, ModifiedAt)
    );
END
GO

IF OBJECT_ID(N'source.CustomerChanges', N'U') IS NULL
BEGIN
    CREATE TABLE source.CustomerChanges
    (
        CustomerId nvarchar(20) NOT NULL,
        CustomerName nvarchar(100) NOT NULL,
        Email nvarchar(160) NOT NULL,
        RegionCode nvarchar(20) NOT NULL,
        LoadBatchId int NOT NULL,
        ModifiedAt datetime2(0) NOT NULL,
        CONSTRAINT PK_SourceCustomerChanges PRIMARY KEY (CustomerId, ModifiedAt)
    );
END
GO

IF OBJECT_ID(N'source.ProductChanges', N'U') IS NULL
BEGIN
    CREATE TABLE source.ProductChanges
    (
        ProductCode nvarchar(20) NOT NULL,
        ProductName nvarchar(100) NOT NULL,
        Category nvarchar(80) NOT NULL,
        StandardPrice decimal(18,2) NOT NULL,
        LoadBatchId int NOT NULL,
        ModifiedAt datetime2(0) NOT NULL,
        CONSTRAINT PK_SourceProductChanges PRIMARY KEY (ProductCode, ModifiedAt)
    );
END
GO

IF OBJECT_ID(N'source.SalesOrderChanges', N'U') IS NULL
BEGIN
    CREATE TABLE source.SalesOrderChanges
    (
        SalesOrderId nvarchar(30) NOT NULL,
        SalesDate date NOT NULL,
        CustomerId nvarchar(20) NOT NULL,
        ProductCode nvarchar(20) NOT NULL,
        Quantity int NOT NULL,
        UnitPrice decimal(18,2) NOT NULL,
        LoadBatchId int NOT NULL,
        ModifiedAt datetime2(0) NOT NULL,
        CONSTRAINT PK_SourceSalesOrderChanges PRIMARY KEY (SalesOrderId, ModifiedAt)
    );
END
GO

IF OBJECT_ID(N'stg.RegionDelta', N'U') IS NULL SELECT TOP 0 * INTO stg.RegionDelta FROM source.RegionChanges;
IF OBJECT_ID(N'stg.CustomerDelta', N'U') IS NULL SELECT TOP 0 * INTO stg.CustomerDelta FROM source.CustomerChanges;
IF OBJECT_ID(N'stg.ProductDelta', N'U') IS NULL SELECT TOP 0 * INTO stg.ProductDelta FROM source.ProductChanges;
IF OBJECT_ID(N'stg.SalesOrderDelta', N'U') IS NULL SELECT TOP 0 * INTO stg.SalesOrderDelta FROM source.SalesOrderChanges;
GO

IF OBJECT_ID(N'dw.DimRegion', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimRegion
    (
        RegionKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimRegion PRIMARY KEY,
        RegionCode nvarchar(20) NOT NULL CONSTRAINT UQ_DimRegion_RegionCode UNIQUE,
        RegionName nvarchar(100) NOT NULL,
        LastModifiedAt datetime2(0) NOT NULL
    );
END
GO

IF OBJECT_ID(N'dw.DimCustomer', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimCustomer
    (
        CustomerKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimCustomer PRIMARY KEY,
        CustomerId nvarchar(20) NOT NULL CONSTRAINT UQ_DimCustomer_CustomerId UNIQUE,
        CustomerName nvarchar(100) NOT NULL,
        Email nvarchar(160) NOT NULL,
        RegionCode nvarchar(20) NOT NULL,
        LastModifiedAt datetime2(0) NOT NULL
    );
END
GO

IF OBJECT_ID(N'dw.DimProduct', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimProduct
    (
        ProductKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimProduct PRIMARY KEY,
        ProductCode nvarchar(20) NOT NULL CONSTRAINT UQ_DimProduct_ProductCode UNIQUE,
        ProductName nvarchar(100) NOT NULL,
        Category nvarchar(80) NOT NULL,
        StandardPrice decimal(18,2) NOT NULL,
        LastModifiedAt datetime2(0) NOT NULL
    );
END
GO

IF OBJECT_ID(N'dw.DimDate', N'U') IS NULL
BEGIN
    CREATE TABLE dw.DimDate
    (
        DateKey int NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
        FullDate date NOT NULL CONSTRAINT UQ_DimDate_FullDate UNIQUE,
        CalendarYear int NOT NULL,
        CalendarQuarter tinyint NOT NULL,
        MonthNumber tinyint NOT NULL,
        MonthName nvarchar(20) NOT NULL
    );
END
GO

IF OBJECT_ID(N'dw.FactSales', N'U') IS NULL
BEGIN
    CREATE TABLE dw.FactSales
    (
        SalesKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactSales PRIMARY KEY,
        SalesOrderId nvarchar(30) NOT NULL CONSTRAINT UQ_FactSales_SalesOrderId UNIQUE,
        DateKey int NOT NULL,
        CustomerKey int NOT NULL,
        ProductKey int NOT NULL,
        RegionKey int NOT NULL,
        Quantity int NOT NULL,
        UnitPrice decimal(18,2) NOT NULL,
        SalesAmount decimal(18,2) NOT NULL,
        LastModifiedAt datetime2(0) NOT NULL,
        CONSTRAINT FK_FactSales_DimDate FOREIGN KEY (DateKey) REFERENCES dw.DimDate(DateKey),
        CONSTRAINT FK_FactSales_DimCustomer FOREIGN KEY (CustomerKey) REFERENCES dw.DimCustomer(CustomerKey),
        CONSTRAINT FK_FactSales_DimProduct FOREIGN KEY (ProductKey) REFERENCES dw.DimProduct(ProductKey),
        CONSTRAINT FK_FactSales_DimRegion FOREIGN KEY (RegionKey) REFERENCES dw.DimRegion(RegionKey)
    );
END
GO

IF OBJECT_ID(N'etl.Watermark', N'U') IS NULL
BEGIN
    CREATE TABLE etl.Watermark
    (
        EntityName sysname NOT NULL CONSTRAINT PK_Watermark PRIMARY KEY,
        LastModifiedAt datetime2(0) NOT NULL
    );
END
GO

IF OBJECT_ID(N'etl.LoadAudit', N'U') IS NULL
BEGIN
    CREATE TABLE etl.LoadAudit
    (
        LoadAuditId int IDENTITY(1,1) NOT NULL CONSTRAINT PK_LoadAudit PRIMARY KEY,
        BatchName nvarchar(100) NOT NULL,
        StartedAt datetime2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        FinishedAt datetime2(0) NULL,
        RowsRegion int NOT NULL DEFAULT 0,
        RowsCustomer int NOT NULL DEFAULT 0,
        RowsProduct int NOT NULL DEFAULT 0,
        RowsSales int NOT NULL DEFAULT 0,
        Status nvarchar(20) NOT NULL DEFAULT N'Running'
    );
END
GO
