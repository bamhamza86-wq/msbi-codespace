USE [DW];
GO

MERGE source.RegionChanges AS tgt
USING (VALUES
    (N'NORTH', N'North Region', 1, CONVERT(datetime2(0), '2026-01-01T08:00:00')),
    (N'SOUTH', N'South Region', 1, CONVERT(datetime2(0), '2026-01-01T08:00:00')),
    (N'EAST',  N'East Region',  1, CONVERT(datetime2(0), '2026-01-01T08:00:00'))
) AS src (RegionCode, RegionName, LoadBatchId, ModifiedAt)
ON tgt.RegionCode = src.RegionCode AND tgt.ModifiedAt = src.ModifiedAt
WHEN NOT MATCHED THEN INSERT (RegionCode, RegionName, LoadBatchId, ModifiedAt)
VALUES (src.RegionCode, src.RegionName, src.LoadBatchId, src.ModifiedAt);
GO

MERGE source.CustomerChanges AS tgt
USING (VALUES
    (N'C001', N'Contoso Paris',  N'paris@contoso.example',  N'NORTH', 1, CONVERT(datetime2(0), '2026-01-01T09:00:00')),
    (N'C002', N'Fabrikam Lyon',  N'lyon@fabrikam.example',  N'SOUTH', 1, CONVERT(datetime2(0), '2026-01-01T09:00:00')),
    (N'C003', N'Northwind Lille', N'lille@northwind.example', N'EAST', 1, CONVERT(datetime2(0), '2026-01-01T09:00:00'))
) AS src (CustomerId, CustomerName, Email, RegionCode, LoadBatchId, ModifiedAt)
ON tgt.CustomerId = src.CustomerId AND tgt.ModifiedAt = src.ModifiedAt
WHEN NOT MATCHED THEN INSERT (CustomerId, CustomerName, Email, RegionCode, LoadBatchId, ModifiedAt)
VALUES (src.CustomerId, src.CustomerName, src.Email, src.RegionCode, src.LoadBatchId, src.ModifiedAt);
GO

MERGE source.ProductChanges AS tgt
USING (VALUES
    (N'P001', N'SQL Server Advisory', N'Services', 1200.00, 1, CONVERT(datetime2(0), '2026-01-01T10:00:00')),
    (N'P002', N'Data Pipeline Build',  N'Services',  820.00, 1, CONVERT(datetime2(0), '2026-01-01T10:00:00')),
    (N'P003', N'Support Pack',         N'Support',   150.00, 1, CONVERT(datetime2(0), '2026-01-01T10:00:00'))
) AS src (ProductCode, ProductName, Category, StandardPrice, LoadBatchId, ModifiedAt)
ON tgt.ProductCode = src.ProductCode AND tgt.ModifiedAt = src.ModifiedAt
WHEN NOT MATCHED THEN INSERT (ProductCode, ProductName, Category, StandardPrice, LoadBatchId, ModifiedAt)
VALUES (src.ProductCode, src.ProductName, src.Category, src.StandardPrice, src.LoadBatchId, src.ModifiedAt);
GO

MERGE source.SalesOrderChanges AS tgt
USING (VALUES
    (N'SO-001', CONVERT(date, '2026-01-05'), N'C001', N'P001', 2, 1200.00, 1, CONVERT(datetime2(0), '2026-01-05T12:00:00')),
    (N'SO-002', CONVERT(date, '2026-01-07'), N'C002', N'P002', 1,  800.00, 1, CONVERT(datetime2(0), '2026-01-07T12:00:00')),
    (N'SO-003', CONVERT(date, '2026-01-09'), N'C003', N'P003', 5,  150.00, 1, CONVERT(datetime2(0), '2026-01-09T12:00:00')),
    (N'SO-004', CONVERT(date, '2026-02-01'), N'C001', N'P002', 3,  820.00, 1, CONVERT(datetime2(0), '2026-02-01T12:00:00'))
) AS src (SalesOrderId, SalesDate, CustomerId, ProductCode, Quantity, UnitPrice, LoadBatchId, ModifiedAt)
ON tgt.SalesOrderId = src.SalesOrderId AND tgt.ModifiedAt = src.ModifiedAt
WHEN NOT MATCHED THEN INSERT (SalesOrderId, SalesDate, CustomerId, ProductCode, Quantity, UnitPrice, LoadBatchId, ModifiedAt)
VALUES (src.SalesOrderId, src.SalesDate, src.CustomerId, src.ProductCode, src.Quantity, src.UnitPrice, src.LoadBatchId, src.ModifiedAt);
GO
