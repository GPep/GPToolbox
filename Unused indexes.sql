 SELECT db_name() AS DatabaseName, object_name(i.object_id) AS TableName, i.type, i.type_desc, 
  ps.page_count as [Page_Count],  
 CONVERT(decimal(18,2), ps.page_count * 8 / 1024.0) AS [Total Size (MB)],  
 CONVERT(decimal(18,2), ps.avg_fragmentation_in_percent) AS [Frag %],  
 i.name AS [Unused Index], s.user_updates, s.user_seeks, s.user_scans, s.user_lookups
 FROM sys.indexes i
 LEFT JOIN sys.dm_db_index_usage_stats s ON s.object_id = i.object_id
       AND i.index_id = s.index_id
       AND s.database_id = db_id()
LEFT JOIN sys.dm_db_index_physical_stats(db_id(),NULL,NULL,NULL,NULL) AS ps
On ps.index_id = s.index_id
AND ps.database_id = s.database_id
AND ps.object_id = s.object_id
 WHERE objectproperty(i.object_id, 'IsIndexable') = 1
 AND objectproperty(i.object_id, 'IsIndexed') = 1
 AND i.type <> 1 
 AND (s.index_id is null
 OR s.user_updates > 0 and s.user_seeks = 0 and s.user_scans = 0 and s.user_lookups = 0)
 ORDER BY object_name(i.object_id) ASC 