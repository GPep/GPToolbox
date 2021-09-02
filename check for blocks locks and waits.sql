-- view blocked requests

USE [master]
GO
SELECT  session_id
 ,blocking_session_id
 ,wait_time
 ,wait_type
 ,last_wait_type
 ,wait_resource
 ,transaction_isolation_level
 ,lock_timeout
FROM sys.dm_exec_requests
WHERE blocking_session_id <> 0
GO


-- view locking in particular databases (user) for only active sessions - this should be constantly changing

USE [master]
GO
SELECT   tl.resource_type
 ,req.blocking_session_id
 ,tl.resource_associated_entity_id
 ,tl.request_status
 ,tl.request_mode
 ,tl.request_session_id
 ,tl.resource_description
 ,db.name AS 'Database Name'
 ,ex_ses.status
FROM sys.dm_tran_locks tl
INNER JOIN sys.databases AS db
on tl.resource_database_id = db.database_id
INNER JOIN sys.dm_exec_requests as req
ON tl.request_session_id= req.session_id
INNER JOIN sys.dm_exec_sessions ex_ses
ON tl.request_session_id = ex_ses.session_id
--WHERE db.name = 'Images'
WHERE tl.resource_database_id > 4 -- view user databases only
GO

-- this reports on blocked or blocking processes and gives you an idea of the kind of waits occuring.

USE [master]
GO
SELECT   w.session_id
 ,w.wait_duration_ms
 ,w.wait_type
 ,w.blocking_session_id
 ,w.resource_description
 ,s.program_name
 ,t.text
 ,t.dbid,
 db_name(t.dbid)
 ,s.cpu_time
 ,s.memory_usage
FROM sys.dm_os_waiting_tasks w
INNER JOIN sys.dm_exec_sessions s
ON w.session_id = s.session_id
INNER JOIN sys.dm_exec_requests r
ON s.session_id = r.session_id
OUTER APPLY sys.dm_exec_sql_text (r.sql_handle) t
WHERE s.is_user_process = 1
GO


USE master;
GO
EXEC sp_who 'active';
GO
EXEC sp_who2 'active';
GO


-- most recent sql handle to see last statement executed..
SELECT  t.text,
        QUOTENAME(OBJECT_SCHEMA_NAME(t.objectid, t.dbid)) + '.'
        + QUOTENAME(OBJECT_NAME(t.objectid, t.dbid)) proc_name,
        c.connect_time,
        s.last_request_start_time,
        s.last_request_end_time,
        s.status
FROM    sys.dm_exec_connections c
JOIN    sys.dm_exec_sessions s
        ON c.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) t
WHERE   c.session_id = 121;--your blocking spid


-- Check for open transactions for a SPID

SELECT  st.transaction_id,
        at.name,
        at.transaction_begin_time,
        at.transaction_state,
        at.transaction_status
FROM    sys.dm_tran_session_transactions st
JOIN    sys.dm_tran_active_transactions at
        ON st.transaction_id = at.transaction_id
WHERE   st.session_id = 121;--your blocking spid