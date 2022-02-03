SELECT OBJECT_NAME(sys.stats.OBJECT_ID) AS TableName,
sys.columns.name AS ColumnName,
sys.stats.name AS StatisticsName
FROM sys.stats
INNER JOIN sys.stats_columns ON sys.stats.OBJECT_ID = sys.stats_columns.OBJECT_ID
AND sys.stats.stats_id = sys.stats_columns.stats_id
INNER JOIN sys.columns ON sys.stats.OBJECT_ID = sys.columns.OBJECT_ID
AND sys.stats_columns.column_id = sys.columns.column_id
WHERE sys.stats.is_incremental = 1