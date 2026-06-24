USE [DW];
GO

MERGE source.RegionChanges AS tgt
USING (VALUES
    (N'WEST', N'West Region', 2, CONVERT(datetime2(0), '2026-03-01T08:00:00'))
) AS src (RegionCode, RegionName, LoadBatchId, ModifiedAt)
ON tgt.RegionCode = src.RegionCode AND tgt.ModifiedAt = src.ModifiedAt
WHEN NOT MATCHED THEN INSERT (RegionCode, RegionName, LoadBatchId, ModifiedAt)
VALUES (src.RegionCode, src.RegionName, src.LoadBatchId, src.ModifiedAt);
GO

MERGE source.CustomerChanges AS tgt
USING (VALUES
    (N'C002', N'Fabrikam Lyon Metropole', N'lyon@fabrikam.example', N'SOUTH', 2, CONVERT(datetime2(0), '2026-03-01T09:00:00')),
    (N'C004', N'Adventure Nantes',        N'nantes@adventure.example', N'WEST', 2, CONVERT(datetime2(0), '2026-03-01T09:00:00'))
) AS src (CustomerId, CustomerName, Email, RegionCode, LoadBatchId, ModifiedAt)
ON tgt.CustomerId = src.CustomerId AND tgt.ModifiedAt = src.ModifiedAt
WHEN NOT MATCHED THEN INSERT (CustomerId, CustomerName, Email, RegionCode, LoadBatchId, ModifiedAt)
VALUES (src.CustomerId, src.CustomerName, src.Email, src.RegionCode, src.LoadBatchId, src.ModifiedAt);
GO

MERGE source.ProductChanges AS tgt
USING (VALUES
    (N'P004', N'Data Quality Audit', N'Services', 45.00, 2, CONVERT(datetime2(0), '2026-03-01T10:00:00'))
) AS src (ProductCode, ProductName, Category, StandardPrice, LoadBatchId, ModifiedAt)
ON tgt.ProductCode = src.ProductCode AND tgt.ModifiedAt = src.ModifiedAt
WHEN NOT MATCHED THEN INSERT (ProductCode, ProductName, Category, StandardPrice, LoadBatchId, ModifiedAt)
VALUES (src.ProductCode, src.ProductName, src.Category, src.StandardPrice, src.LoadBatchId, src.ModifiedAt);
GO

MERGE source.SalesOrderChanges AS tgt
USING (VALUES
    (N'SO-003', CONVERT(date, '2026-01-09'), N'C003', N'P003', 6,  150.00, 2, CONVERT(datetime2(0), '2026-03-02T12:00:00')),
    (N'SO-005', CONVERT(date, '2026-03-03'), N'C004', N'P004', 10,  45.00, 2, CONVERT(datetime2(0), '2026-03-03T12:00:00')),
    (N'SO-006', CONVERT(date, '2026-03-04'), N'C002', N'P001', 1, 1250.00, 2, CONVERT(datetime2(0), '2026-03-04T12:00:00'))
) AS src (SalesOrderId, SalesDate, CustomerId, ProductCode, Quantity, UnitPrice, LoadBatchId, ModifiedAt)
ON tgt.SalesOrderId = src.SalesOrderId AND tgt.ModifiedAt = src.ModifiedAt
WHEN NOT MATCHED THEN INSERT (SalesOrderId, SalesDate, CustomerId, ProductCode, Quantity, UnitPrice, LoadBatchId, ModifiedAt)
VALUES (src.SalesOrderId, src.SalesDate, src.CustomerId, src.ProductCode, src.Quantity, src.UnitPrice, src.LoadBatchId, src.ModifiedAt);
GO
