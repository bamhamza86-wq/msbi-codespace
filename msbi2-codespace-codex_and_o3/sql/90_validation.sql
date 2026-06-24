USE [DW];
GO

DECLARE @Errors table (Message nvarchar(4000) NOT NULL);

IF (SELECT COUNT(*) FROM dw.DimRegion) <> 4
    INSERT INTO @Errors VALUES (N'DimRegion rowcount must be 4');

IF (SELECT COUNT(*) FROM dw.DimCustomer) <> 4
    INSERT INTO @Errors VALUES (N'DimCustomer rowcount must be 4');

IF (SELECT COUNT(*) FROM dw.DimProduct) <> 4
    INSERT INTO @Errors VALUES (N'DimProduct rowcount must be 4');

IF (SELECT COUNT(*) FROM dw.FactSales) <> 6
    INSERT INTO @Errors VALUES (N'FactSales rowcount must be 6');

IF (SELECT CONVERT(decimal(18,2), SUM(SalesAmount)) FROM dw.FactSales) <> CONVERT(decimal(18,2), 8260.00)
    INSERT INTO @Errors VALUES (N'FactSales amount must be 8260.00');

IF NOT EXISTS (SELECT 1 FROM dw.DimCustomer WHERE CustomerId = N'C002' AND CustomerName = N'Fabrikam Lyon Metropole')
    INSERT INTO @Errors VALUES (N'C002 delta update was not applied');

IF NOT EXISTS (SELECT 1 FROM dw.FactSales WHERE SalesOrderId = N'SO-003' AND Quantity = 6 AND SalesAmount = 900.00)
    INSERT INTO @Errors VALUES (N'SO-003 delta update was not applied');

IF (SELECT COUNT(*) FROM etl.Watermark) <> 4
    INSERT INTO @Errors VALUES (N'Watermarks missing');

IF NOT EXISTS (SELECT 1 FROM rpt.vSalesByRegion WHERE RegionCode = N'WEST' AND SalesAmount = 450.00)
    INSERT INTO @Errors VALUES (N'SSRS/SSAS reporting view vSalesByRegion is missing WEST amount');

IF EXISTS (SELECT 1 FROM @Errors)
BEGIN
    DECLARE @Message nvarchar(4000) = (SELECT STRING_AGG(Message, N'; ') FROM @Errors);
    THROW 51000, @Message, 1;
END

SELECT
    N'MSBI2_VALIDATION_OK' AS Status,
    (SELECT COUNT(*) FROM dw.FactSales) AS FactSalesRows,
    (SELECT CONVERT(decimal(18,2), SUM(SalesAmount)) FROM dw.FactSales) AS TotalSalesAmount;
GO
