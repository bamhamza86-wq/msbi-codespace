USE [DW];
GO

EXEC etl.usp_LoadDeltaAll @BatchName = N'delta-batch-002';
GO
