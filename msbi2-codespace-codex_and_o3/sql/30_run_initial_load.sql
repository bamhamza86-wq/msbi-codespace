USE [DW];
GO

EXEC etl.usp_LoadDeltaAll @BatchName = N'initial-batch-001';
GO
