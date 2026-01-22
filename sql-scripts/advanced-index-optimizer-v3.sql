/*==============================================================================
Advanced SQL Server Index Optimizer v3.0 - SSMS Ready
Deep analysis + monitoring + A/B test workflow for insert performance

Highlights:
- Captures index health snapshots (usage, fragmentation, insert pressure)
- Recommends disable candidates and redundant indexes
- Surfaces insert hotspots and plan regressions (Query Store)
- Heuristic scoring for Columnstore candidates (CCI/NCCI)

Usage (typical):
1) Set @RunLabel = 'BASELINE', run with your normal workload window.
2) Disable selected indexes (generated below), run workload.
3) Set @RunLabel = 'AFTER', @CompareLabel = 'BASELINE', run again.
4) Review regressions/improvements and decide to keep or rollback.
==============================================================================*/

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @RunLabel SYSNAME = 'BASELINE';       -- 'BASELINE' or 'AFTER'
DECLARE @CompareLabel SYSNAME = NULL;         -- set to 'BASELINE' when @RunLabel = 'AFTER'
DECLARE @CaptureIndexSnapshot BIT = 1;
DECLARE @CaptureQueryStore BIT = 1;

DECLARE @MinRows BIGINT = 1000;
DECLARE @MinPages BIGINT = 100;
DECLARE @MinSizeMB DECIMAL(9,1) = 5.0;
DECLARE @UsageRatioMax DECIMAL(9,2) = 5.0;
DECLARE @UnusedDays INT = 14;
DECLARE @FragReorg DECIMAL(5,1) = 10.0;
DECLARE @FragRebuild DECIMAL(5,1) = 30.0;

DECLARE @QueryStoreWindowMinutes INT = 60;
DECLARE @RegressionPctThreshold DECIMAL(6,2) = 25.0;

DECLARE @CCIMinRows BIGINT = 1000000;
DECLARE @CCIMinSizeMB DECIMAL(10,1) = 512.0;
DECLARE @CCIReadUpdateRatio DECIMAL(9,2) = 20.0;
DECLARE @NCCIMinRows BIGINT = 500000;
DECLARE @NCCIMinSizeMB DECIMAL(10,1) = 256.0;

DECLARE @SnapshotBatchId UNIQUEIDENTIFIER = NEWID();
DECLARE @CaptureTime DATETIME2(0) = SYSUTCDATETIME();

PRINT 'Parameters: RunLabel=' + @RunLabel
    + ' | MinRows=' + CAST(@MinRows AS VARCHAR(20))
    + ' | MinPages=' + CAST(@MinPages AS VARCHAR(20))
    + ' | UsageRatioMax=' + CAST(@UsageRatioMax AS VARCHAR(20))
    + ' | QueryStoreWindowMinutes=' + CAST(@QueryStoreWindowMinutes AS VARCHAR(20));

/*------------------------------------------------------------------------------
Schema + tables (lightweight persistence for A/B testing)
------------------------------------------------------------------------------*/
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dba')
BEGIN
    EXEC('CREATE SCHEMA dba');
END;

IF OBJECT_ID('dba.IndexHealthSnapshot', 'U') IS NULL
BEGIN
    CREATE TABLE dba.IndexHealthSnapshot
    (
        snapshot_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        snapshot_batch_id UNIQUEIDENTIFIER NOT NULL,
        capture_time DATETIME2(0) NOT NULL,
        run_label SYSNAME NULL,
        object_id INT NOT NULL,
        index_id INT NOT NULL,
        schema_name SYSNAME NOT NULL,
        table_name SYSNAME NOT NULL,
        index_name SYSNAME NOT NULL,
        index_type_desc NVARCHAR(60) NOT NULL,
        is_primary_key BIT NOT NULL,
        is_unique BIT NOT NULL,
        is_disabled BIT NOT NULL,
        has_filter BIT NOT NULL,
        row_count BIGINT NOT NULL,
        total_pages BIGINT NOT NULL,
        used_pages BIGINT NOT NULL,
        table_size_mb DECIMAL(18,1) NOT NULL,
        reads BIGINT NULL,
        user_updates BIGINT NULL,
        read_update_ratio DECIMAL(18,2) NULL,
        last_user_seek DATETIME NULL,
        last_user_scan DATETIME NULL,
        last_user_lookup DATETIME NULL,
        avg_frag_pct DECIMAL(6,2) NULL,
        leaf_insert_count BIGINT NULL,
        leaf_page_split_count BIGINT NULL,
        page_latch_wait_ms BIGINT NULL,
        forwarded_record_count BIGINT NULL
    );
END;

IF OBJECT_ID('dba.IndexChangeLog', 'U') IS NULL
BEGIN
    CREATE TABLE dba.IndexChangeLog
    (
        change_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        change_time DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
        action_type NVARCHAR(30) NOT NULL,
        schema_name SYSNAME NOT NULL,
        table_name SYSNAME NOT NULL,
        index_name SYSNAME NULL,
        index_id INT NULL,
        action_sql NVARCHAR(MAX) NULL,
        notes NVARCHAR(4000) NULL
    );
END;

IF OBJECT_ID('dba.QueryStoreInsertSnapshot', 'U') IS NULL
BEGIN
    CREATE TABLE dba.QueryStoreInsertSnapshot
    (
        snapshot_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        snapshot_batch_id UNIQUEIDENTIFIER NOT NULL,
        capture_time DATETIME2(0) NOT NULL,
        run_label SYSNAME NULL,
        query_id BIGINT NOT NULL,
        plan_id BIGINT NOT NULL,
        avg_duration_ms DECIMAL(18,2) NULL,
        avg_cpu_ms DECIMAL(18,2) NULL,
        avg_logical_io_reads BIGINT NULL,
        avg_logical_io_writes BIGINT NULL,
        avg_rowcount DECIMAL(18,2) NULL,
        execution_count BIGINT NULL,
        query_text NVARCHAR(4000) NULL
    );
END;

/*------------------------------------------------------------------------------
Capture index snapshot
------------------------------------------------------------------------------*/
IF @CaptureIndexSnapshot = 1
BEGIN
    ;WITH IndexUsage AS
    (
        SELECT object_id,
               index_id,
               user_seeks + user_scans + user_lookups AS reads,
               user_updates,
               user_seeks,
               user_scans,
               user_lookups,
               last_user_seek,
               last_user_scan,
               last_user_lookup
        FROM sys.dm_db_index_usage_stats
        WHERE database_id = DB_ID()
    ),
    FragStats AS
    (
        SELECT object_id,
               index_id,
               AVG(avg_fragmentation_in_percent) AS avg_frag_pct,
               SUM(page_count) AS total_pages,
               SUM(record_count) AS record_count,
               SUM(forwarded_record_count) AS forwarded_record_count
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED')
        GROUP BY object_id, index_id
    ),
    OpStats AS
    (
        SELECT object_id,
               index_id,
               SUM(leaf_insert_count) AS leaf_insert_count,
               SUM(leaf_page_split_count) AS leaf_page_split_count,
               SUM(page_latch_wait_in_ms) AS page_latch_wait_ms
        FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL)
        GROUP BY object_id, index_id
    ),
    TableStats AS
    (
        SELECT object_id,
               SUM(row_count) AS row_count,
               SUM(used_page_count) AS used_pages,
               SUM(reserved_page_count) AS reserved_pages
        FROM sys.dm_db_partition_stats
        GROUP BY object_id
    ),
    IndexDetails AS
    (
        SELECT i.object_id,
               i.index_id,
               ISNULL(i.name, 'HEAP') AS index_name,
               i.type_desc,
               i.is_primary_key,
               i.is_unique,
               i.is_disabled,
               i.has_filter,
               s.name AS schema_name,
               o.name AS table_name
        FROM sys.indexes i
        INNER JOIN sys.objects o ON i.object_id = o.object_id
        INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
        WHERE o.type = 'U'
          AND o.is_ms_shipped = 0
    )
    INSERT INTO dba.IndexHealthSnapshot
    (
        snapshot_batch_id,
        capture_time,
        run_label,
        object_id,
        index_id,
        schema_name,
        table_name,
        index_name,
        index_type_desc,
        is_primary_key,
        is_unique,
        is_disabled,
        has_filter,
        row_count,
        total_pages,
        used_pages,
        table_size_mb,
        reads,
        user_updates,
        read_update_ratio,
        last_user_seek,
        last_user_scan,
        last_user_lookup,
        avg_frag_pct,
        leaf_insert_count,
        leaf_page_split_count,
        page_latch_wait_ms,
        forwarded_record_count
    )
    SELECT
        @SnapshotBatchId,
        @CaptureTime,
        @RunLabel,
        id.object_id,
        id.index_id,
        id.schema_name,
        id.table_name,
        id.index_name,
        id.type_desc,
        id.is_primary_key,
        id.is_unique,
        id.is_disabled,
        id.has_filter,
        ISNULL(ts.row_count, 0) AS row_count,
        ISNULL(fs.total_pages, 0) AS total_pages,
        ISNULL(ts.used_pages, 0) AS used_pages,
        CAST(ISNULL(ts.used_pages, 0) * 8.0 / 1024.0 AS DECIMAL(18,1)) AS table_size_mb,
        iu.reads,
        iu.user_updates,
        CASE
            WHEN COALESCE(iu.user_updates, 0) = 0 THEN 999.0
            ELSE (COALESCE(iu.reads, 0) * 1.0) / NULLIF(iu.user_updates, 0)
        END AS read_update_ratio,
        iu.last_user_seek,
        iu.last_user_scan,
        iu.last_user_lookup,
        fs.avg_frag_pct,
        os.leaf_insert_count,
        os.leaf_page_split_count,
        os.page_latch_wait_ms,
        fs.forwarded_record_count
    FROM IndexDetails id
    LEFT JOIN TableStats ts ON id.object_id = ts.object_id
    LEFT JOIN IndexUsage iu ON id.object_id = iu.object_id AND id.index_id = iu.index_id
    LEFT JOIN FragStats fs ON id.object_id = fs.object_id AND id.index_id = fs.index_id
    LEFT JOIN OpStats os ON id.object_id = os.object_id AND id.index_id = os.index_id;

    PRINT 'Index snapshot captured: ' + CAST(@SnapshotBatchId AS VARCHAR(36));
END;

/*------------------------------------------------------------------------------
Capture Query Store snapshot (INSERT/MERGE workload)
------------------------------------------------------------------------------*/
DECLARE @QueryStoreState SYSNAME = (SELECT actual_state_desc FROM sys.database_query_store_options);

IF @CaptureQueryStore = 1 AND @QueryStoreState IN ('READ_WRITE', 'READ_ONLY')
BEGIN
    INSERT INTO dba.QueryStoreInsertSnapshot
    (
        snapshot_batch_id,
        capture_time,
        run_label,
        query_id,
        plan_id,
        avg_duration_ms,
        avg_cpu_ms,
        avg_logical_io_reads,
        avg_logical_io_writes,
        avg_rowcount,
        execution_count,
        query_text
    )
    SELECT
        @SnapshotBatchId,
        @CaptureTime,
        @RunLabel,
        q.query_id,
        p.plan_id,
        CAST(SUM(rs.avg_duration * rs.count_executions)
             / NULLIF(SUM(rs.count_executions), 0) / 1000.0 AS DECIMAL(18,2)) AS avg_duration_ms,
        CAST(SUM(rs.avg_cpu_time * rs.count_executions)
             / NULLIF(SUM(rs.count_executions), 0) / 1000.0 AS DECIMAL(18,2)) AS avg_cpu_ms,
        CAST(SUM(rs.avg_logical_io_reads * rs.count_executions)
             / NULLIF(SUM(rs.count_executions), 0) AS BIGINT) AS avg_logical_io_reads,
        CAST(SUM(rs.avg_logical_io_writes * rs.count_executions)
             / NULLIF(SUM(rs.count_executions), 0) AS BIGINT) AS avg_logical_io_writes,
        CAST(SUM(rs.avg_rowcount * rs.count_executions)
             / NULLIF(SUM(rs.count_executions), 0) AS DECIMAL(18,2)) AS avg_rowcount,
        SUM(rs.count_executions) AS execution_count,
        LEFT(REPLACE(REPLACE(qt.query_sql_text, CHAR(10), ' '), CHAR(13), ' '), 4000) AS query_text
    FROM sys.query_store_query_text qt
    INNER JOIN sys.query_store_query q ON q.query_text_id = qt.query_text_id
    INNER JOIN sys.query_store_plan p ON p.query_id = q.query_id
    INNER JOIN sys.query_store_runtime_stats rs ON rs.plan_id = p.plan_id
    INNER JOIN sys.query_store_runtime_stats_interval rsi
        ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
    WHERE rsi.start_time >= DATEADD(MINUTE, -@QueryStoreWindowMinutes, SYSUTCDATETIME())
      AND (
            UPPER(qt.query_sql_text) LIKE '%INSERT%'
         OR UPPER(qt.query_sql_text) LIKE '%MERGE%'
         OR UPPER(qt.query_sql_text) LIKE '%BULK INSERT%'
         OR UPPER(qt.query_sql_text) LIKE '%OPENROWSET%'
      )
    GROUP BY q.query_id, p.plan_id, qt.query_sql_text;

    PRINT 'Query Store snapshot captured: ' + CAST(@SnapshotBatchId AS VARCHAR(36));
END
ELSE IF @CaptureQueryStore = 1
BEGIN
    PRINT 'Query Store is OFF. Enable it to capture insert baselines.';
END;

/*------------------------------------------------------------------------------
Result set 1: Unused or low-value indexes (disable first, then decide drop)
------------------------------------------------------------------------------*/
;WITH LatestSnap AS
(
    SELECT TOP 1 snapshot_batch_id
    FROM dba.IndexHealthSnapshot
    WHERE run_label = @RunLabel
    ORDER BY capture_time DESC
),
Snap AS
(
    SELECT s.*
    FROM dba.IndexHealthSnapshot s
    INNER JOIN LatestSnap l ON s.snapshot_batch_id = l.snapshot_batch_id
),
LastRead AS
(
    SELECT s.*,
           lr.last_read
    FROM Snap s
    CROSS APPLY
    (
        SELECT MAX(v) AS last_read
        FROM (VALUES (s.last_user_seek), (s.last_user_scan), (s.last_user_lookup)) AS t(v)
    ) lr
)
SELECT
    'DISABLE_CANDIDATE' AS category,
    lr.schema_name + '.' + lr.table_name AS table_name,
    lr.index_name,
    lr.table_size_mb,
    lr.row_count,
    lr.reads,
    lr.user_updates,
    lr.read_update_ratio,
    lr.last_read,
    lr.leaf_page_split_count,
    lr.leaf_insert_count,
    CASE
        WHEN lr.reads = 0 AND lr.user_updates > 0 THEN 'Never read; maintenance only'
        WHEN lr.read_update_ratio <= @UsageRatioMax THEN 'Reads low vs updates'
        ELSE 'Review'
    END AS rationale,
    'ALTER INDEX [' + lr.index_name + '] ON [' + lr.schema_name + '].[' + lr.table_name + '] DISABLE;' AS disable_sql,
    'ALTER INDEX [' + lr.index_name + '] ON [' + lr.schema_name + '].[' + lr.table_name + '] REBUILD;' AS rollback_sql,
    CASE
        WHEN lr.read_update_ratio <= @UsageRatioMax
        THEN CAST((@UsageRatioMax - lr.read_update_ratio) * 100.0 / @UsageRatioMax AS DECIMAL(6,1))
        ELSE 0.0
    END AS est_insert_gain_pct
FROM LastRead lr
WHERE lr.index_id > 0
  AND lr.is_primary_key = 0
  AND lr.is_unique = 0
  AND lr.is_disabled = 0
  AND lr.has_filter = 0
  AND lr.row_count >= @MinRows
  AND lr.table_size_mb >= @MinSizeMB
  AND (
        (COALESCE(lr.reads, 0) = 0 AND COALESCE(lr.user_updates, 0) > 0)
     OR (COALESCE(lr.read_update_ratio, 999) <= @UsageRatioMax)
  )
  AND (lr.last_read IS NULL OR lr.last_read < DATEADD(DAY, -@UnusedDays, GETDATE()))
ORDER BY lr.user_updates DESC, lr.table_size_mb DESC;

/*------------------------------------------------------------------------------
Result set 2: Redundant/overlapping nonclustered indexes (coverage based)
------------------------------------------------------------------------------*/
;WITH Indexes AS
(
    SELECT i.object_id,
           i.index_id,
           i.name AS index_name,
           i.is_primary_key,
           i.is_unique,
           i.has_filter,
           s.name AS schema_name,
           o.name AS table_name
    FROM sys.indexes i
    INNER JOIN sys.objects o ON i.object_id = o.object_id
    INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE o.type = 'U'
      AND i.type_desc = 'NONCLUSTERED'
      AND i.is_primary_key = 0
      AND i.is_unique = 0
      AND i.has_filter = 0
),
KeyCols AS
(
    SELECT object_id, index_id, key_ordinal, column_id
    FROM sys.index_columns
    WHERE is_included_column = 0
),
IncludeCols AS
(
    SELECT object_id, index_id, column_id
    FROM sys.index_columns
    WHERE is_included_column = 1
),
KeyCounts AS
(
    SELECT object_id, index_id, COUNT(*) AS key_count
    FROM KeyCols
    GROUP BY object_id, index_id
),
IndexColsAgg AS
(
    SELECT i.object_id,
           i.index_id,
           STRING_AGG(CASE WHEN ic.is_included_column = 0 THEN QUOTENAME(c.name) END, ',')
               WITHIN GROUP (ORDER BY ic.key_ordinal) AS key_cols,
           STRING_AGG(CASE WHEN ic.is_included_column = 1 THEN QUOTENAME(c.name) END, ',')
               WITHIN GROUP (ORDER BY c.name) AS include_cols
    FROM sys.indexes i
    INNER JOIN sys.index_columns ic
        ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    INNER JOIN sys.columns c
        ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE i.type_desc = 'NONCLUSTERED'
    GROUP BY i.object_id, i.index_id
),
Redundant AS
(
    SELECT a.object_id,
           a.schema_name,
           a.table_name,
           a.index_id AS redundant_index_id,
           a.index_name AS redundant_index_name,
           b.index_id AS covering_index_id,
           b.index_name AS covering_index_name
    FROM Indexes a
    INNER JOIN Indexes b
        ON a.object_id = b.object_id
       AND a.index_id <> b.index_id
    INNER JOIN KeyCounts ak
        ON ak.object_id = a.object_id AND ak.index_id = a.index_id
    INNER JOIN KeyCounts bk
        ON bk.object_id = b.object_id AND bk.index_id = b.index_id
    WHERE ak.key_count <= bk.key_count
      AND NOT EXISTS
      (
          SELECT 1
          FROM KeyCols ka
          WHERE ka.object_id = a.object_id
            AND ka.index_id = a.index_id
            AND NOT EXISTS
            (
                SELECT 1
                FROM KeyCols kb
                WHERE kb.object_id = b.object_id
                  AND kb.index_id = b.index_id
                  AND kb.key_ordinal = ka.key_ordinal
                  AND kb.column_id = ka.column_id
            )
      )
      AND NOT EXISTS
      (
          SELECT 1
          FROM IncludeCols ia
          WHERE ia.object_id = a.object_id
            AND ia.index_id = a.index_id
            AND NOT EXISTS
            (
                SELECT 1
                FROM IncludeCols ib
                WHERE ib.object_id = b.object_id
                  AND ib.index_id = b.index_id
                  AND ib.column_id = ia.column_id
            )
            AND NOT EXISTS
            (
                SELECT 1
                FROM KeyCols kb
                WHERE kb.object_id = b.object_id
                  AND kb.index_id = b.index_id
                  AND kb.column_id = ia.column_id
            )
      )
)
SELECT
    'REDUNDANT_INDEX' AS category,
    r.schema_name + '.' + r.table_name AS table_name,
    r.redundant_index_name,
    r.covering_index_name,
    ia.key_cols AS redundant_key_cols,
    ia.include_cols AS redundant_include_cols,
    ib.key_cols AS covering_key_cols,
    ib.include_cols AS covering_include_cols,
    'ALTER INDEX [' + r.redundant_index_name + '] ON [' + r.schema_name + '].[' + r.table_name + '] DISABLE;' AS disable_sql,
    'ALTER INDEX [' + r.redundant_index_name + '] ON [' + r.schema_name + '].[' + r.table_name + '] REBUILD;' AS rollback_sql
FROM Redundant r
LEFT JOIN IndexColsAgg ia ON ia.object_id = r.object_id AND ia.index_id = r.redundant_index_id
LEFT JOIN IndexColsAgg ib ON ib.object_id = r.object_id AND ib.index_id = r.covering_index_id
ORDER BY r.schema_name, r.table_name, r.redundant_index_name;

/*------------------------------------------------------------------------------
Result set 3: Insert hotspots and insert-plan tuning hints
------------------------------------------------------------------------------*/
;WITH LatestSnap AS
(
    SELECT TOP 1 snapshot_batch_id
    FROM dba.IndexHealthSnapshot
    WHERE run_label = @RunLabel
    ORDER BY capture_time DESC
),
Snap AS
(
    SELECT s.*
    FROM dba.IndexHealthSnapshot s
    INNER JOIN LatestSnap l ON s.snapshot_batch_id = l.snapshot_batch_id
),
TableAgg AS
(
    SELECT object_id,
           MAX(schema_name) AS schema_name,
           MAX(table_name) AS table_name,
           MAX(row_count) AS row_count,
           MAX(table_size_mb) AS table_size_mb,
           SUM(COALESCE(reads, 0)) AS reads,
           SUM(COALESCE(user_updates, 0)) AS updates
    FROM Snap
    GROUP BY object_id
),
TableOps AS
(
    SELECT object_id,
           SUM(leaf_insert_count) AS leaf_inserts,
           SUM(leaf_page_split_count) AS page_splits,
           SUM(page_latch_wait_ms) AS latch_wait_ms
    FROM sys.dm_db_index_operational_stats(DB_ID(), NULL, NULL, NULL)
    WHERE index_id IN (0, 1)
    GROUP BY object_id
),
IndexCounts AS
(
    SELECT object_id,
           SUM(CASE WHEN type_desc = 'NONCLUSTERED' THEN 1 ELSE 0 END) AS nc_count,
           COUNT(*) AS total_index_count
    FROM sys.indexes
    GROUP BY object_id
),
Triggers AS
(
    SELECT parent_id AS object_id,
           COUNT(*) AS trigger_count
    FROM sys.triggers
    WHERE is_disabled = 0
    GROUP BY parent_id
),
Fks AS
(
    SELECT parent_object_id AS object_id,
           COUNT(*) AS fk_count
    FROM sys.foreign_keys
    WHERE is_disabled = 0
    GROUP BY parent_object_id
),
HeapForwards AS
(
    SELECT object_id,
           SUM(forwarded_record_count) AS forwarded_records
    FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED')
    WHERE index_id = 0
    GROUP BY object_id
)
SELECT
    t.schema_name + '.' + t.table_name AS table_name,
    t.row_count,
    t.table_size_mb,
    t.reads,
    t.updates,
    CASE WHEN t.updates = 0 THEN 999.0 ELSE t.reads * 1.0 / NULLIF(t.updates, 0) END AS table_read_update_ratio,
    COALESCE(o.leaf_inserts, 0) AS leaf_inserts,
    COALESCE(o.page_splits, 0) AS page_splits,
    CAST(COALESCE(o.page_splits, 0) * 1.0 / NULLIF(o.leaf_inserts, 0) AS DECIMAL(9,4)) AS split_rate,
    COALESCE(o.latch_wait_ms, 0) AS latch_wait_ms,
    COALESCE(ic.nc_count, 0) AS nc_index_count,
    COALESCE(ic.total_index_count, 0) AS total_index_count,
    COALESCE(tr.trigger_count, 0) AS trigger_count,
    COALESCE(fk.fk_count, 0) AS fk_count,
    COALESCE(hf.forwarded_records, 0) AS forwarded_records,
    CASE
        WHEN COALESCE(hf.forwarded_records, 0) > 0 THEN
            'Heap forwarded records; consider clustered index or heap rebuild'
        WHEN COALESCE(o.page_splits, 0) > 0
             AND COALESCE(o.leaf_inserts, 0) > 0
             AND (COALESCE(o.page_splits, 0) * 1.0 / NULLIF(o.leaf_inserts, 0)) > 0.2 THEN
            'High page splits; consider fillfactor/OPTIMIZE_FOR_SEQUENTIAL_KEY'
        WHEN COALESCE(ic.nc_count, 0) >= 6 AND t.updates > t.reads THEN
            'Write-heavy with many NC indexes; disable low-value indexes first'
        WHEN COALESCE(tr.trigger_count, 0) > 0 THEN
            'Triggers detected; review trigger cost and batching'
        WHEN COALESCE(fk.fk_count, 0) > 0 THEN
            'FK checks can slow inserts; validate indexing on FK columns'
        ELSE
            'Review insert plan for Sort/Spool/Key Lookup and batch size'
    END AS recommendation
FROM TableAgg t
LEFT JOIN TableOps o ON t.object_id = o.object_id
LEFT JOIN IndexCounts ic ON t.object_id = ic.object_id
LEFT JOIN Triggers tr ON t.object_id = tr.object_id
LEFT JOIN Fks fk ON t.object_id = fk.object_id
LEFT JOIN HeapForwards hf ON t.object_id = hf.object_id
WHERE t.row_count >= @MinRows
ORDER BY COALESCE(o.leaf_inserts, 0) DESC, t.table_size_mb DESC;

/*------------------------------------------------------------------------------
Result set 4: Top INSERT/MERGE queries (Query Store)
------------------------------------------------------------------------------*/
IF EXISTS (SELECT 1 FROM dba.QueryStoreInsertSnapshot WHERE run_label = @RunLabel)
BEGIN
    ;WITH LatestQS AS
    (
        SELECT TOP 1 snapshot_batch_id
        FROM dba.QueryStoreInsertSnapshot
        WHERE run_label = @RunLabel
        ORDER BY capture_time DESC
    ),
    QS AS
    (
        SELECT q.*
        FROM dba.QueryStoreInsertSnapshot q
        INNER JOIN LatestQS l ON q.snapshot_batch_id = l.snapshot_batch_id
    )
    SELECT TOP (50)
        q.query_id,
        q.plan_id,
        q.avg_duration_ms,
        q.avg_cpu_ms,
        q.avg_logical_io_writes,
        q.execution_count,
        q.avg_rowcount,
        q.query_text,
        'Open plan_id in Query Store to review regressions' AS note
    FROM QS q
    ORDER BY q.avg_duration_ms DESC;
END
ELSE
BEGIN
    PRINT 'No Query Store snapshot for this run label.';
END;

/*------------------------------------------------------------------------------
Result set 5: INSERT regressions vs baseline (Query Store)
------------------------------------------------------------------------------*/
IF @CompareLabel IS NOT NULL
   AND EXISTS (SELECT 1 FROM dba.QueryStoreInsertSnapshot WHERE run_label = @CompareLabel)
   AND EXISTS (SELECT 1 FROM dba.QueryStoreInsertSnapshot WHERE run_label = @RunLabel)
BEGIN
    ;WITH BaseSnap AS
    (
        SELECT TOP 1 snapshot_batch_id
        FROM dba.QueryStoreInsertSnapshot
        WHERE run_label = @CompareLabel
        ORDER BY capture_time DESC
    ),
    CurrSnap AS
    (
        SELECT TOP 1 snapshot_batch_id
        FROM dba.QueryStoreInsertSnapshot
        WHERE run_label = @RunLabel
        ORDER BY capture_time DESC
    ),
    Base AS
    (
        SELECT q.*
        FROM dba.QueryStoreInsertSnapshot q
        INNER JOIN BaseSnap b ON q.snapshot_batch_id = b.snapshot_batch_id
    ),
    Curr AS
    (
        SELECT q.*
        FROM dba.QueryStoreInsertSnapshot q
        INNER JOIN CurrSnap c ON q.snapshot_batch_id = c.snapshot_batch_id
    )
    SELECT TOP (50)
        c.query_id,
        c.plan_id,
        c.avg_duration_ms AS after_avg_ms,
        b.avg_duration_ms AS base_avg_ms,
        CAST((c.avg_duration_ms - b.avg_duration_ms) * 100.0
             / NULLIF(b.avg_duration_ms, 0) AS DECIMAL(9,2)) AS delta_pct,
        c.avg_logical_io_writes AS after_io_writes,
        b.avg_logical_io_writes AS base_io_writes,
        c.execution_count,
        c.query_text
    FROM Curr c
    INNER JOIN Base b ON c.query_id = b.query_id AND c.plan_id = b.plan_id
    WHERE (c.avg_duration_ms - b.avg_duration_ms) * 100.0
          / NULLIF(b.avg_duration_ms, 0) >= @RegressionPctThreshold
    ORDER BY delta_pct DESC;
END;

/*------------------------------------------------------------------------------
Result set 6: Columnstore candidates (heuristic scoring)
------------------------------------------------------------------------------*/
;WITH TableStats AS
(
    SELECT t.object_id,
           s.name AS schema_name,
           t.name AS table_name,
           SUM(ps.row_count) AS row_count,
           CAST(SUM(ps.used_page_count) * 8.0 / 1024.0 AS DECIMAL(18,1)) AS size_mb,
           t.is_memory_optimized,
           t.temporal_type
    FROM sys.tables t
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
    INNER JOIN sys.dm_db_partition_stats ps ON t.object_id = ps.object_id
    GROUP BY t.object_id, s.name, t.name, t.is_memory_optimized, t.temporal_type
),
Usage AS
(
    SELECT object_id,
           SUM(user_seeks + user_scans + user_lookups) AS reads,
           SUM(user_scans) AS scans,
           SUM(user_updates) AS updates
    FROM sys.dm_db_index_usage_stats
    WHERE database_id = DB_ID()
    GROUP BY object_id
),
IndexCounts AS
(
    SELECT object_id,
           SUM(CASE WHEN type_desc LIKE '%COLUMNSTORE%' THEN 1 ELSE 0 END) AS columnstore_count,
           SUM(CASE WHEN type_desc = 'NONCLUSTERED' THEN 1 ELSE 0 END) AS nc_count,
           SUM(CASE WHEN index_id = 1 THEN 1 ELSE 0 END) AS has_clustered
    FROM sys.indexes
    GROUP BY object_id
),
EligibleCols AS
(
    SELECT c.object_id,
           STRING_AGG(QUOTENAME(c.name), ',')
               WITHIN GROUP (ORDER BY c.column_id) AS col_list,
           SUM(CASE WHEN c.is_computed = 1 OR c.is_sparse = 1 THEN 1 ELSE 0 END) AS ineligible_count
    FROM sys.columns c
    INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
    WHERE t.name NOT IN ('text', 'ntext', 'image', 'xml', 'geography', 'geometry', 'hierarchyid')
      AND NOT (c.max_length = -1 AND t.name IN ('varchar', 'nvarchar', 'varbinary'))
    GROUP BY c.object_id
),
Heuristic AS
(
    SELECT ts.object_id,
           ts.schema_name,
           ts.table_name,
           ts.row_count,
           ts.size_mb,
           COALESCE(u.reads, 0) AS reads,
           COALESCE(u.scans, 0) AS scans,
           COALESCE(u.updates, 0) AS updates,
           CASE WHEN COALESCE(u.updates, 0) = 0 THEN 999.0
                ELSE COALESCE(u.reads, 0) * 1.0 / NULLIF(u.updates, 0) END AS read_update_ratio,
           CASE WHEN COALESCE(u.reads, 0) = 0 THEN 0.0
                ELSE COALESCE(u.scans, 0) * 1.0 / NULLIF(u.reads, 0) END AS scan_ratio,
           COALESCE(ic.columnstore_count, 0) AS columnstore_count,
           COALESCE(ic.nc_count, 0) AS nc_count,
           COALESCE(ic.has_clustered, 0) AS has_clustered,
           ts.is_memory_optimized,
           ts.temporal_type,
           ec.col_list
    FROM TableStats ts
    LEFT JOIN Usage u ON ts.object_id = u.object_id
    LEFT JOIN IndexCounts ic ON ts.object_id = ic.object_id
    LEFT JOIN EligibleCols ec ON ts.object_id = ec.object_id
),
Scored AS
(
    SELECT h.*,
           CAST(
               CASE
                   WHEN h.row_count >= @CCIMinRows THEN 30
                   ELSE h.row_count * 30.0 / NULLIF(@CCIMinRows, 0)
               END
               + CASE
                   WHEN h.size_mb >= @CCIMinSizeMB THEN 20
                   ELSE h.size_mb * 20.0 / NULLIF(@CCIMinSizeMB, 0)
                 END
               + CASE
                   WHEN h.read_update_ratio >= @CCIReadUpdateRatio THEN 25
                   ELSE h.read_update_ratio * 25.0 / NULLIF(@CCIReadUpdateRatio, 0)
                 END
               + CASE
                   WHEN h.scan_ratio >= 0.6 THEN 15
                   ELSE h.scan_ratio * 15.0 / 0.6
                 END
               + CASE
                   WHEN h.col_list IS NULL THEN 0
                   ELSE 10
                 END
           AS DECIMAL(6,1)) AS cci_score
    FROM Heuristic h
)
SELECT
    s.schema_name + '.' + s.table_name AS table_name,
    s.row_count,
    s.size_mb,
    s.reads,
    s.updates,
    s.read_update_ratio,
    s.scan_ratio,
    s.nc_count,
    s.columnstore_count,
    s.cci_score,
    CASE
        WHEN s.is_memory_optimized = 1 THEN 'Not supported on memory-optimized tables'
        WHEN s.temporal_type <> 0 THEN 'Temporal table; verify compatibility'
        WHEN s.columnstore_count > 0 THEN 'Columnstore already present'
        WHEN s.row_count < @NCCIMinRows AND s.size_mb < @NCCIMinSizeMB THEN 'Below size/row threshold'
        WHEN s.read_update_ratio >= @CCIReadUpdateRatio THEN 'Strong CCI candidate (analytics heavy)'
        WHEN s.read_update_ratio >= 5 AND s.scan_ratio >= 0.3 THEN 'NCCI candidate (hybrid workload)'
        ELSE 'Review manually'
    END AS recommendation,
    CASE
        WHEN s.columnstore_count = 0 AND s.has_clustered = 1
             AND s.read_update_ratio >= @CCIReadUpdateRatio THEN
            'CREATE CLUSTERED COLUMNSTORE INDEX [CCI_' + s.table_name + '] ON [' + s.schema_name + '].[' + s.table_name + '] WITH (DROP_EXISTING = ON);'
        ELSE NULL
    END AS cci_action_sql,
    CASE
        WHEN s.columnstore_count = 0 AND s.col_list IS NOT NULL
             AND s.read_update_ratio >= 5 AND s.scan_ratio >= 0.3 THEN
            'CREATE NONCLUSTERED COLUMNSTORE INDEX [NCCI_' + s.table_name + '] ON [' + s.schema_name + '].[' + s.table_name + '] (' + s.col_list + ');'
        ELSE NULL
    END AS ncci_action_sql
FROM Scored s
WHERE s.row_count >= @MinRows
ORDER BY s.cci_score DESC, s.size_mb DESC;

/*------------------------------------------------------------------------------
Result set 7: Insert optimization playbook (actionable checklist)
------------------------------------------------------------------------------*/
SELECT 'CHECKLIST' AS section, 'Prefer batching (e.g., 5k-50k rows) to reduce log pressure.' AS advice
UNION ALL
SELECT 'CHECKLIST', 'Use TABLOCK + BULK_LOGGED for bulk loads when possible.'
UNION ALL
SELECT 'CHECKLIST', 'Disable nonessential NC indexes for large loads; rebuild after.'
UNION ALL
SELECT 'CHECKLIST', 'If page splits high, use FILLFACTOR or OPTIMIZE_FOR_SEQUENTIAL_KEY on hot indexes.'
UNION ALL
SELECT 'CHECKLIST', 'For heavy transforms, stage into temp table then INSERT with simple join.'
UNION ALL
SELECT 'CHECKLIST', 'Consider partitioning + SWITCH for daily loads.'
UNION ALL
SELECT 'CHECKLIST', 'If insert plan shows Sort/Spool, add supporting indexes or pre-sort data.'
UNION ALL
SELECT 'CHECKLIST', 'Review triggers and foreign keys for overhead on hot tables.'
UNION ALL
SELECT 'CHECKLIST', 'Use Query Store to detect insert regressions after index changes.'
UNION ALL
SELECT 'CHECKLIST', 'If read-heavy analytics, evaluate CCI/NCCI candidates above.';

PRINT 'Done. Review result sets and run actions in controlled tests.';
