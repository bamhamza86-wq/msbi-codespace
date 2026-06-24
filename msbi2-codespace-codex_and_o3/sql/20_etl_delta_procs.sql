USE [DW];
GO

CREATE OR ALTER PROCEDURE etl.usp_LoadDeltaAll
    @BatchName nvarchar(100) = N'delta'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @LoadAuditId int,
        @MinDate datetime2(0) = CONVERT(datetime2(0), '1900-01-01'),
        @RegionWatermark datetime2(0),
        @CustomerWatermark datetime2(0),
        @ProductWatermark datetime2(0),
        @SalesWatermark datetime2(0),
        @RowsRegion int = 0,
        @RowsCustomer int = 0,
        @RowsProduct int = 0,
        @RowsSales int = 0;

    SELECT @RegionWatermark = ISNULL((SELECT LastModifiedAt FROM etl.Watermark WHERE EntityName = N'Region'), @MinDate);
    SELECT @CustomerWatermark = ISNULL((SELECT LastModifiedAt FROM etl.Watermark WHERE EntityName = N'Customer'), @MinDate);
    SELECT @ProductWatermark = ISNULL((SELECT LastModifiedAt FROM etl.Watermark WHERE EntityName = N'Product'), @MinDate);
    SELECT @SalesWatermark = ISNULL((SELECT LastModifiedAt FROM etl.Watermark WHERE EntityName = N'Sales'), @MinDate);

    INSERT INTO etl.LoadAudit (BatchName) VALUES (@BatchName);
    SET @LoadAuditId = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO stg.RegionDelta (RegionCode, RegionName, LoadBatchId, ModifiedAt)
        SELECT s.RegionCode, s.RegionName, s.LoadBatchId, s.ModifiedAt
        FROM source.RegionChanges s
        WHERE s.ModifiedAt > @RegionWatermark
          AND NOT EXISTS (SELECT 1 FROM stg.RegionDelta d WHERE d.RegionCode = s.RegionCode AND d.ModifiedAt = s.ModifiedAt);
        SET @RowsRegion = @@ROWCOUNT;

        INSERT INTO stg.CustomerDelta (CustomerId, CustomerName, Email, RegionCode, LoadBatchId, ModifiedAt)
        SELECT s.CustomerId, s.CustomerName, s.Email, s.RegionCode, s.LoadBatchId, s.ModifiedAt
        FROM source.CustomerChanges s
        WHERE s.ModifiedAt > @CustomerWatermark
          AND NOT EXISTS (SELECT 1 FROM stg.CustomerDelta d WHERE d.CustomerId = s.CustomerId AND d.ModifiedAt = s.ModifiedAt);
        SET @RowsCustomer = @@ROWCOUNT;

        INSERT INTO stg.ProductDelta (ProductCode, ProductName, Category, StandardPrice, LoadBatchId, ModifiedAt)
        SELECT s.ProductCode, s.ProductName, s.Category, s.StandardPrice, s.LoadBatchId, s.ModifiedAt
        FROM source.ProductChanges s
        WHERE s.ModifiedAt > @ProductWatermark
          AND NOT EXISTS (SELECT 1 FROM stg.ProductDelta d WHERE d.ProductCode = s.ProductCode AND d.ModifiedAt = s.ModifiedAt);
        SET @RowsProduct = @@ROWCOUNT;

        INSERT INTO stg.SalesOrderDelta (SalesOrderId, SalesDate, CustomerId, ProductCode, Quantity, UnitPrice, LoadBatchId, ModifiedAt)
        SELECT s.SalesOrderId, s.SalesDate, s.CustomerId, s.ProductCode, s.Quantity, s.UnitPrice, s.LoadBatchId, s.ModifiedAt
        FROM source.SalesOrderChanges s
        WHERE s.ModifiedAt > @SalesWatermark
          AND NOT EXISTS (SELECT 1 FROM stg.SalesOrderDelta d WHERE d.SalesOrderId = s.SalesOrderId AND d.ModifiedAt = s.ModifiedAt);
        SET @RowsSales = @@ROWCOUNT;

        ;WITH LatestRegion AS
        (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY RegionCode ORDER BY ModifiedAt DESC) AS rn
            FROM stg.RegionDelta
            WHERE ModifiedAt > @RegionWatermark
        )
        MERGE dw.DimRegion AS tgt
        USING (SELECT RegionCode, RegionName, ModifiedAt FROM LatestRegion WHERE rn = 1) AS src
        ON tgt.RegionCode = src.RegionCode
        WHEN MATCHED THEN UPDATE SET
            RegionName = src.RegionName,
            LastModifiedAt = src.ModifiedAt
        WHEN NOT MATCHED THEN INSERT (RegionCode, RegionName, LastModifiedAt)
            VALUES (src.RegionCode, src.RegionName, src.ModifiedAt);

        ;WITH LatestCustomer AS
        (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY CustomerId ORDER BY ModifiedAt DESC) AS rn
            FROM stg.CustomerDelta
            WHERE ModifiedAt > @CustomerWatermark
        )
        MERGE dw.DimCustomer AS tgt
        USING (SELECT CustomerId, CustomerName, Email, RegionCode, ModifiedAt FROM LatestCustomer WHERE rn = 1) AS src
        ON tgt.CustomerId = src.CustomerId
        WHEN MATCHED THEN UPDATE SET
            CustomerName = src.CustomerName,
            Email = src.Email,
            RegionCode = src.RegionCode,
            LastModifiedAt = src.ModifiedAt
        WHEN NOT MATCHED THEN INSERT (CustomerId, CustomerName, Email, RegionCode, LastModifiedAt)
            VALUES (src.CustomerId, src.CustomerName, src.Email, src.RegionCode, src.ModifiedAt);

        ;WITH LatestProduct AS
        (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY ProductCode ORDER BY ModifiedAt DESC) AS rn
            FROM stg.ProductDelta
            WHERE ModifiedAt > @ProductWatermark
        )
        MERGE dw.DimProduct AS tgt
        USING (SELECT ProductCode, ProductName, Category, StandardPrice, ModifiedAt FROM LatestProduct WHERE rn = 1) AS src
        ON tgt.ProductCode = src.ProductCode
        WHEN MATCHED THEN UPDATE SET
            ProductName = src.ProductName,
            Category = src.Category,
            StandardPrice = src.StandardPrice,
            LastModifiedAt = src.ModifiedAt
        WHEN NOT MATCHED THEN INSERT (ProductCode, ProductName, Category, StandardPrice, LastModifiedAt)
            VALUES (src.ProductCode, src.ProductName, src.Category, src.StandardPrice, src.ModifiedAt);

        INSERT INTO dw.DimDate (DateKey, FullDate, CalendarYear, CalendarQuarter, MonthNumber, MonthName)
        SELECT DISTINCT
            CONVERT(int, CONVERT(char(8), s.SalesDate, 112)) AS DateKey,
            s.SalesDate,
            DATEPART(year, s.SalesDate),
            DATEPART(quarter, s.SalesDate),
            DATEPART(month, s.SalesDate),
            DATENAME(month, s.SalesDate)
        FROM stg.SalesOrderDelta s
        WHERE s.ModifiedAt > @SalesWatermark
          AND NOT EXISTS (SELECT 1 FROM dw.DimDate d WHERE d.FullDate = s.SalesDate);

        ;WITH LatestSales AS
        (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY SalesOrderId ORDER BY ModifiedAt DESC) AS rn
            FROM stg.SalesOrderDelta
            WHERE ModifiedAt > @SalesWatermark
        )
        MERGE dw.FactSales AS tgt
        USING
        (
            SELECT
                s.SalesOrderId,
                CONVERT(int, CONVERT(char(8), s.SalesDate, 112)) AS DateKey,
                c.CustomerKey,
                p.ProductKey,
                r.RegionKey,
                s.Quantity,
                s.UnitPrice,
                CONVERT(decimal(18,2), s.Quantity * s.UnitPrice) AS SalesAmount,
                s.ModifiedAt
            FROM LatestSales s
            JOIN dw.DimCustomer c ON c.CustomerId = s.CustomerId
            JOIN dw.DimProduct p ON p.ProductCode = s.ProductCode
            JOIN dw.DimRegion r ON r.RegionCode = c.RegionCode
            WHERE s.rn = 1
        ) AS src
        ON tgt.SalesOrderId = src.SalesOrderId
        WHEN MATCHED THEN UPDATE SET
            DateKey = src.DateKey,
            CustomerKey = src.CustomerKey,
            ProductKey = src.ProductKey,
            RegionKey = src.RegionKey,
            Quantity = src.Quantity,
            UnitPrice = src.UnitPrice,
            SalesAmount = src.SalesAmount,
            LastModifiedAt = src.ModifiedAt
        WHEN NOT MATCHED THEN INSERT
            (SalesOrderId, DateKey, CustomerKey, ProductKey, RegionKey, Quantity, UnitPrice, SalesAmount, LastModifiedAt)
            VALUES
            (src.SalesOrderId, src.DateKey, src.CustomerKey, src.ProductKey, src.RegionKey, src.Quantity, src.UnitPrice, src.SalesAmount, src.ModifiedAt);

        MERGE etl.Watermark AS tgt
        USING
        (
            SELECT N'Region' AS EntityName, ISNULL(MAX(ModifiedAt), @RegionWatermark) AS LastModifiedAt FROM source.RegionChanges
            UNION ALL SELECT N'Customer', ISNULL(MAX(ModifiedAt), @CustomerWatermark) FROM source.CustomerChanges
            UNION ALL SELECT N'Product', ISNULL(MAX(ModifiedAt), @ProductWatermark) FROM source.ProductChanges
            UNION ALL SELECT N'Sales', ISNULL(MAX(ModifiedAt), @SalesWatermark) FROM source.SalesOrderChanges
        ) AS src
        ON tgt.EntityName = src.EntityName
        WHEN MATCHED THEN UPDATE SET LastModifiedAt = src.LastModifiedAt
        WHEN NOT MATCHED THEN INSERT (EntityName, LastModifiedAt) VALUES (src.EntityName, src.LastModifiedAt);

        UPDATE etl.LoadAudit
        SET FinishedAt = SYSUTCDATETIME(),
            RowsRegion = @RowsRegion,
            RowsCustomer = @RowsCustomer,
            RowsProduct = @RowsProduct,
            RowsSales = @RowsSales,
            Status = N'Succeeded'
        WHERE LoadAuditId = @LoadAuditId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        UPDATE etl.LoadAudit
        SET FinishedAt = SYSUTCDATETIME(),
            Status = N'Failed'
        WHERE LoadAuditId = @LoadAuditId;

        THROW;
    END CATCH
END;
GO

CREATE OR ALTER VIEW rpt.vSalesByRegion
AS
SELECT
    r.RegionCode,
    r.RegionName,
    COUNT_BIG(*) AS SalesCount,
    SUM(f.SalesAmount) AS SalesAmount
FROM dw.FactSales f
JOIN dw.DimRegion r ON r.RegionKey = f.RegionKey
GROUP BY r.RegionCode, r.RegionName;
GO

CREATE OR ALTER VIEW rpt.vMonthlySales
AS
SELECT
    d.CalendarYear,
    d.MonthNumber,
    d.MonthName,
    COUNT_BIG(*) AS SalesCount,
    SUM(f.SalesAmount) AS SalesAmount
FROM dw.FactSales f
JOIN dw.DimDate d ON d.DateKey = f.DateKey
GROUP BY d.CalendarYear, d.MonthNumber, d.MonthName;
GO

CREATE OR ALTER VIEW rpt.vTopCustomers
AS
SELECT
    c.CustomerId,
    c.CustomerName,
    r.RegionName,
    COUNT_BIG(*) AS SalesCount,
    SUM(f.SalesAmount) AS SalesAmount
FROM dw.FactSales f
JOIN dw.DimCustomer c ON c.CustomerKey = f.CustomerKey
JOIN dw.DimRegion r ON r.RegionCode = c.RegionCode
GROUP BY c.CustomerId, c.CustomerName, r.RegionName;
GO
