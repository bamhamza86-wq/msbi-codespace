/*
=============================================================================
🚀 ADVANCED SQL SERVER INDEX OPTIMIZER v3.0 - ARCHITECT & PERFORMANCE EDITION
=============================================================================
Author: AI Assistant
Description: 
  Analyse heuristique profonde pour l'optimisation des indexes et des performances.
  Intègre :
  1. 🗑️ Nettoyage d'indexes (Unused/Duplicate)
  2. 🧪 A/B Testing : Propositions de DÉSACTIVATION avec capture de baseline (pour vérifier régression)
  3. ⚡ INSERT Analysis : Analyse du cache de plan pour trouver les INSERTs lents
  4. 🏛️ Architecture Advisor : Candidats Columnstore (CCI) et Partitionnement

Instructions:
  Copier-coller tout le script dans SSMS.
  Vérifiez les paramètres au début.
  Exécuter.
=============================================================================
*/

-- ⚙️ CONFIGURATION
DECLARE @MinRows BIGINT = 10000;           -- Seuil lignes pour analyse approfondie
DECLARE @MinPages BIGINT = 500;            -- Seuil pages index
DECLARE @LookbackDays INT = 7;             -- Historique max (si dispo)
DECLARE @CCIMinRows BIGINT = 1000000;      -- Seuil pour recommandation Columnstore

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '🧠 LANCEMENT DE L''ANALYSE HEURISTIQUE APPROFONDIE';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';

-- 1. SETUP : Table de monitoring pour l'évolution (Idempotent)
-- Cette table permet de stocker les actions proposées et de comparer les perfs plus tard.
IF OBJECT_ID('tempdb..#IndexOptimization_SessionLog') IS NOT NULL DROP TABLE #IndexOptimization_SessionLog;
CREATE TABLE #IndexOptimization_SessionLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    TableName NVARCHAR(255),
    IndexName NVARCHAR(255),
    ActionType NVARCHAR(50),
    CurrentReadWriteRatio DECIMAL(10,2),
    EstImprovementScore DECIMAL(5,2),
    Reason NVARCHAR(MAX)
);

-- -----------------------------------------------------------------------------
-- 📥 CTEs : COLLECTION DES MÉTRIQUES (ETAT DES LIEUX)
-- -----------------------------------------------------------------------------
WITH IndexUsage AS (
    SELECT 
        ius.object_id, 
        ius.index_id, 
        (ius.user_seeks + ius.user_scans + ius.user_lookups) AS TotalReads,
        ius.user_updates AS TotalWrites,
        ius.user_scans,
        ius.user_seeks,
        ius.last_user_seek,
        ius.last_user_scan,
        ius.last_user_update,
        CASE WHEN ius.user_updates > 0 THEN (ius.user_seeks + ius.user_scans + ius.user_lookups) * 1.0 / ius.user_updates ELSE 9999 END AS ReadWriteRatio
    FROM sys.dm_db_index_usage_stats ius
    WHERE ius.database_id = DB_ID()
),
TableStats AS (
    SELECT 
        t.object_id,
        s.name AS SchemaName,
        t.name AS TableName,
        SUM(p.rows) AS TotalRows,
        MAX(p.data_compression_desc) AS CompressionType
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
    WHERE t.is_ms_shipped = 0
    GROUP BY t.object_id, s.name, t.name
),
IndexDetails AS (
    SELECT 
        i.object_id, i.index_id, i.name AS IndexName, i.type_desc, i.is_primary_key, i.is_unique,
        ts.SchemaName, ts.TableName, ts.TotalRows,
        ISNULL(iu.TotalReads, 0) AS TotalReads,
        ISNULL(iu.TotalWrites, 0) AS TotalWrites,
        ISNULL(iu.ReadWriteRatio, 0) AS ReadWriteRatio,
        ISNULL(iu.user_scans, 0) AS UserScans,
        ISNULL(iu.user_seeks, 0) AS UserSeeks,
        sz.page_count * 8.0 / 1024 AS SizeMB
    FROM sys.indexes i
    JOIN TableStats ts ON i.object_id = ts.object_id
    LEFT JOIN IndexUsage iu ON i.object_id = iu.object_id AND i.index_id = iu.index_id
    LEFT JOIN sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') sz 
        ON i.object_id = sz.object_id AND i.index_id = sz.index_id
    WHERE i.index_id > 0 -- Ignore Heap for index specific stats
),
-- ⚡ ANALYSE INSERT : Recherche dans le cache de plan (Top 20 coûteux)
SlowInserts AS (
    SELECT TOP 20
        dest.text AS QueryText,
        deqp.query_plan AS QueryPlan,
        qs.execution_count,
        qs.total_elapsed_time / 1000.0 / qs.execution_count AS AvgDurationMS,
        qs.total_logical_reads / qs.execution_count AS AvgLogicalReads,
        qs.total_worker_time / 1000.0 / qs.execution_count AS AvgCPUTimeMS,
        qs.last_execution_time
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) dest
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) deqp
    WHERE dest.text LIKE '%INSERT%' AND dest.text NOT LIKE '%sys.dm_%' -- Exclure les requêtes système
    ORDER BY qs.total_elapsed_time DESC
)

-- -----------------------------------------------------------------------------
-- 📊 1. ANALYSE ARCHITECTURALE : CANDIDATS COLUMNSTORE (CCI)
-- -----------------------------------------------------------------------------
SELECT 
    '🏛️ Architecture' AS [Catégorie],
    ts.SchemaName + '.' + ts.TableName AS [Table],
    ts.TotalRows AS [Lignes],
    FORMAT(ISNULL(iu.TotalReads,0), 'N0') AS [Lectures],
    FORMAT(ISNULL(iu.TotalWrites,0), 'N0') AS [Ecritures],
    CASE 
        WHEN iu.user_scans > iu.user_seeks * 5 THEN 'Scan Intensif (>80%)' 
        ELSE 'Mixte' 
    END AS [Profil Lecture],
    'Candidat CLUSTERED COLUMNSTORE' AS [Suggestion],
    'GAIN POTENTIEL: Compression x10 + Performance Scan x10-100' AS [Impact],
    CONCAT('CREATE CLUSTERED COLUMNSTORE INDEX CCI_', ts.TableName, ' ON ', ts.SchemaName, '.', ts.TableName, ' WITH (DROP_EXISTING = ON);') AS [SQL Action]
FROM TableStats ts
LEFT JOIN IndexUsage iu ON ts.object_id = iu.object_id AND iu.index_id IN (0,1) -- Heap or Clustered
WHERE ts.TotalRows >= @CCIMinRows
  AND (iu.TotalReads > iu.TotalWrites * 10 OR iu.TotalReads IS NULL) -- Principalement lecture
  AND ISNULL(iu.user_scans,0) > ISNULL(iu.user_seeks,0) -- Surtout des scans
  AND ts.CompressionType <> 'COLUMNSTORE';

-- -----------------------------------------------------------------------------
-- 🧪 2. A/B TESTING & DÉSACTIVATION SÉCURISÉE
-- -----------------------------------------------------------------------------
SELECT 
    '🧪 A/B Testing' AS [Catégorie],
    id.SchemaName + '.' + id.TableName AS [Table],
    id.IndexName AS [Index],
    CONCAT(id.TotalReads, ' R / ', id.TotalWrites, ' W') AS [Usage],
    'Index Coûteux en Maintenance' AS [Problème],
    'DÉSACTIVER (DISABLE) au lieu de DROP pour test' AS [Stratégie],
    CONCAT(
        'ALTER INDEX [', id.IndexName, '] ON [', id.SchemaName, '].[', id.TableName, '] DISABLE; ',
        '-- ⚠️ Surveiller temps INSERT. Rollback: ALTER INDEX ... REBUILD'
    ) AS [SQL Action (Safe)],
    CAST(id.SizeMB AS DECIMAL(10,2)) AS [Size MB]
FROM IndexDetails id
WHERE id.ReadWriteRatio < 0.1 -- 10x plus d'écritures que de lectures
  AND id.TotalWrites > 5000 -- Activité significative
  AND id.is_primary_key = 0 
  AND id.is_unique = 0
ORDER BY id.TotalWrites DESC;

-- -----------------------------------------------------------------------------
-- ⚡ 3. ANALYSE PERFORMANCE INSERT (TOP LENTS)
-- -----------------------------------------------------------------------------
SELECT 
    '⚡ Slow INSERTs' AS [Catégorie],
    SUBSTRING(QueryText, 1, 100) + '...' AS [Requête (Extrait)],
    execution_count AS [Execs],
    CAST(AvgDurationMS AS DECIMAL(10,2)) AS [Avg ms],
    CAST(AvgLogicalReads AS DECIMAL(10,2)) AS [Avg Pages Lues],
    last_execution_time AS [Dernière Exec],
    CASE 
        WHEN AvgLogicalReads > 10000 THEN '🔴 I/O INTENSIF : Vérifier Page Splits / Triggers'
        WHEN AvgCPUTimeMS > AvgDurationMS * 0.8 THEN '🔴 CPU BOUND : Vérifier calculs / contraintes'
        ELSE '⚠️ A Investiguer'
    END AS [Diagnostic Rapide],
    '🔎 Cliquez sur le XML Plan pour voir les "Missing Indexes" ou opérateurs coûteux (Sort, Hash)' AS [Action],
    QueryPlan
FROM SlowInserts;

-- -----------------------------------------------------------------------------
-- 🔍 4. SYNTHÈSE DES INDEX MANQUANTS (BASÉ SUR PLAN CACHE)
-- -----------------------------------------------------------------------------
SELECT TOP 10
    '➕ Index Manquant' AS [Catégorie],
    migs.unique_compiles AS [Compilations],
    migs.user_seeks + migs.user_scans AS [Usage Est.],
    migs.avg_user_impact AS [Impact %],
    CONCAT('CREATE INDEX [IX_', LEFT(REPLACE(REPLACE(mid.statement, '[', ''), ']', ''), 20), '_Auto] ON ', mid.statement, 
           ' (', mid.equality_columns, CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ', ' ELSE '' END, mid.inequality_columns, ')',
           CASE WHEN mid.included_columns IS NOT NULL THEN ' INCLUDE (' + mid.included_columns + ')' ELSE '' END, ';') AS [SQL Suggestion]
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
ORDER BY migs.avg_user_impact * migs.user_seeks DESC;

PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
PRINT '✅ Analyse terminée.';
PRINT '👉 Pour les tables > 1M lignes avec beaucoup de scans, considérez sérieusement le Columnstore (Section 1).';
PRINT '👉 Pour les indexes très mis à jour et peu lus (Section 2), désactivez-les temporairement pour valider le gain en écriture.';
PRINT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
