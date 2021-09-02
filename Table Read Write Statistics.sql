DECLARE @dbid int
SELECT @dbid = db_id('tools')

SELECT TableName = object_name(s.object_id),
       Reads = SUM(user_seeks + user_scans + user_lookups), Writes =  SUM(user_updates)
FROM sys.dm_db_index_usage_stats AS s
INNER JOIN sys.indexes AS i
ON s.object_id = i.object_id
AND i.index_id = s.index_id
WHERE objectproperty(s.object_id,'IsUserTable') = 1
AND s.database_id = @dbid
--AND object_name(s.object_id) = ''
GROUP BY object_name(s.object_id)
ORDER BY object_name(s.object_id), writes DESC