SELECT top(10)
(qs.total_logical_reads + qs.total_logical_writes) AS total_logical_IO,
qs.execution_count,
 qs.total_worker_time / execution_count AS AVG_CPU
 ,(qs.total_elapsed_time / execution_count) /1000000 AS AVG_ELAPSED_Secs
 ,qs.total_logical_reads / execution_count AS AVG_LOGICAL_READS
 ,qs.total_logical_writes / execution_count AS AVG_LOGICAL_WRITES
 ,qs.total_physical_reads  / execution_count AS AVG_PHYSICAL_READS,
(SELECT SUBSTRING(text, qs.statement_start_offset/2 + 1,
(CASE WHEN qs.statement_end_offset = -1
THEN LEN(CONVERT(nvarchar(MAX),text)) * 2
ELSE qs.statement_end_offset
END - qs.statement_start_offset)/2)
FROM sys.dm_exec_sql_text(qs.sql_handle)) AS query_text,
CASE
WHEN DB_NAME(dest.dbid) IS NULL THEN 'AdhocSQL'
ELSE DB_NAME(dest.dbid) END Databasename,
qs.last_execution_time,
qs.last_elapsed_time/1000000 AS last_elapsed_time_Secs
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as dest
ORDER BY (total_logical_reads + total_logical_writes) DESC;
