/*
=============================================================================
🛠️ INFRASTRUCTURE DE MONITORING (PERSISTANT)
=============================================================================
Description: 
  Ce script crée les tables et procédures nécessaires pour historiser 
  l'usage des indexes et mesurer l'impact des optimisations dans le temps.
  
  Objets créés :
  - Schema: [Optimization]
  - Table: [Optimization].[IndexUsageHistory] (Snapshots quotidiens)
  - Procédure: [Optimization].[usp_CaptureIndexStats] (A planifier)
  - Procédure: [Optimization].[usp_AnalyzeEvolution] (Rapport d'évolution)
=============================================================================
*/

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Optimization')
BEGIN
    EXEC('CREATE SCHEMA [Optimization]')
END
GO

-- 1. Table d'historique des stats d'utilisation
IF OBJECT_ID('[Optimization].[IndexUsageHistory]') IS NULL
BEGIN
    CREATE TABLE [Optimization].[IndexUsageHistory] (
        HistoryID BIGINT IDENTITY(1,1) PRIMARY KEY,
        CaptureDate DATETIME DEFAULT GETDATE(),
        DatabaseName NVARCHAR(128),
        SchemaName NVARCHAR(128),
        TableName NVARCHAR(128),
        IndexName NVARCHAR(128),
        IndexID INT,
        ObjectID INT,
        UserSeeks BIGINT,
        UserScans BIGINT,
        UserLookups BIGINT,
        UserUpdates BIGINT,
        TotalReads AS (UserSeeks + UserScans + UserLookups),
        ReadWriteRatio DECIMAL(18,2)
    );
    CREATE CLUSTERED INDEX CIX_IndexUsageHistory_Date ON [Optimization].[IndexUsageHistory](CaptureDate);
END
GO

-- 2. Procédure de capture (A planifier via SQL Agent - ex: chaque nuit)
CREATE OR ALTER PROCEDURE [Optimization].[usp_CaptureIndexStats]
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO [Optimization].[IndexUsageHistory] 
    (DatabaseName, SchemaName, TableName, IndexName, IndexID, ObjectID, UserSeeks, UserScans, UserLookups, UserUpdates, ReadWriteRatio)
    SELECT 
        DB_NAME(),
        s.name,
        o.name,
        ISNULL(i.name, 'HEAP'),
        i.index_id,
        i.object_id,
        ius.user_seeks,
        ius.user_scans,
        ius.user_lookups,
        ius.user_updates,
        CASE WHEN ius.user_updates > 0 THEN (ius.user_seeks + ius.user_scans + ius.user_lookups) * 1.0 / ius.user_updates ELSE 0 END
    FROM sys.dm_db_index_usage_stats ius
    JOIN sys.indexes i ON ius.object_id = i.object_id AND ius.index_id = i.index_id
    JOIN sys.objects o ON i.object_id = o.object_id
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE ius.database_id = DB_ID()
      AND o.is_ms_shipped = 0;
      
    PRINT '✅ Capture des statistiques d''index terminée.';
END
GO

-- 3. Procédure d'analyse d'évolution (Impact des changements)
CREATE OR ALTER PROCEDURE [Optimization].[usp_AnalyzeEvolution]
    @TableName NVARCHAR(128) = NULL,
    @DaysBack INT = 30
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        h.TableName,
        h.IndexName,
        MIN(h.CaptureDate) AS FirstCapture,
        MAX(h.CaptureDate) AS LastCapture,
        MAX(h.UserUpdates) - MIN(h.UserUpdates) AS Updates_Delta,
        MAX(h.TotalReads) - MIN(h.TotalReads) AS Reads_Delta,
        CASE 
            WHEN (MAX(h.UserUpdates) - MIN(h.UserUpdates)) = 0 THEN 0
            ELSE (MAX(h.TotalReads) - MIN(h.TotalReads)) * 1.0 / NULLIF((MAX(h.UserUpdates) - MIN(h.UserUpdates)),0)
        END AS Period_ReadWriteRatio
    FROM [Optimization].[IndexUsageHistory] h
    WHERE h.CaptureDate >= DATEADD(day, -@DaysBack, GETDATE())
      AND (@TableName IS NULL OR h.TableName = @TableName)
    GROUP BY h.TableName, h.IndexName
    ORDER BY Updates_Delta DESC;
END
GO
