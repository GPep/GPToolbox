SELECT instance_name, cntr_value 
INTO #redo1
FROM sys.dm_os_performance_counters
WHERE object_name  LIKE '%:Database Replica%' 
  AND counter_name = 'Redone Bytes/sec';

SELECT instance_name, cntr_value 
INTO #send1
FROM sys.dm_os_performance_counters 
WHERE object_name  LIKE '%:Database Replica%' 
  AND counter_name = 'Log Bytes Received/sec';

WAITFOR DELAY '00:00:01';

SELECT instance_name, cntr_value 
INTO #redo2
FROM sys.dm_os_performance_counters
WHERE object_name  LIKE '%:Database Replica%' 
  AND counter_name = 'Redone Bytes/sec';

SELECT instance_name, cntr_value 
INTO #send2
FROM sys.dm_os_performance_counters 
WHERE object_name  LIKE '%:Database Replica%' 
  AND counter_name = 'Log Bytes Received/sec';

SELECT
      DB_NAME(rs.database_id) AS 'Database'
      ,r.replica_server_name AS 'SecondaryReplica'
      ,CONVERT(DECIMAL(10,2), rs.log_send_queue_size / 1024.0) AS 'LogSendQueueSize'
      ,CONVERT(DECIMAL(10,2), send_rate / 1024.0 / 1024.0) AS 'LogSendRate'
      ,CONVERT(DECIMAL(10,2), log_send_queue_size / CASE WHEN send_rate = 0 THEN 1 ELSE send_rate / 1024.0 END) AS 'SendLatency'
      ,CONVERT(DECIMAL(10,2), rs.redo_queue_size / 1024.0) AS 'RedoQueueSize'
      ,CONVERT(DECIMAL(10,2), redo_rate.redo_rate / 1024.0 / 1024.0) AS 'RedoRate' 
      ,CONVERT(DECIMAL(10,2), rs.redo_queue_size / CASE WHEN redo_rate.redo_rate = 0 THEN 1 ELSE redo_rate.redo_rate / 1024.0 END) AS 'RedoLatency'
FROM sys.dm_hadr_database_replica_states rs
JOIN sys.availability_replicas r ON r.group_id = rs.group_id AND r.replica_id = rs.replica_id
JOIN (SELECT l1.instance_name, l2.cntr_value - l1.cntr_value redo_rate
      FROM #redo1 l1
      JOIN #redo2 l2 ON l2.instance_name = l1.instance_name
      ) redo_rate ON redo_rate.instance_name = DB_NAME(rs.database_id)
JOIN (SELECT l1.instance_name, l2.cntr_value - l1.cntr_value send_rate
      FROM #send1 l1
      JOIN #send2 l2 ON l2.instance_name = l1.instance_name
      ) send_rate ON send_rate.instance_name = DB_NAME(rs.database_id);

DROP TABLE #send1;
DROP TABLE #send2;
DROP TABLE #redo1;
DROP TABLE #redo2;