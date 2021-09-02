
------------------------------
-- Create the Event Session --
------------------------------
 
IF EXISTS(SELECT * FROM sys.server_event_sessions WHERE name='LongRunningQuery')
DROP EVENT SESSION LongRunningQuery ON SERVER
GO
-- Create Event
CREATE EVENT SESSION LongRunningQuery
ON SERVER
-- Add event to capture event
ADD EVENT sqlserver.rpc_completed
(
-- Add action - event property ; can't add query_hash in R2
ACTION (sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.client_app_name,
sqlserver.username, sqlserver.client_hostname, sqlserver.session_nt_username)
-- Predicate - time 1000 milisecond
WHERE (
duration > 1000 --by leaving off the event name, you can easily change to capture diff events
--AND sqlserver.client_hostname <> 'A' --cant use NOT LIKE prior to 2012
)
--by leaving off the event name, you can easily change to capture diff events
),
ADD EVENT sqlserver.sql_statement_completed
-- or do sqlserver.rpc_completed, though getting the actual SP name seems overly difficult
(
-- Add action - event property ; can't add query_hash in R2
ACTION (sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.client_app_name,
sqlserver.username, sqlserver.client_hostname, sqlserver.session_nt_username)
-- Predicate - time 1000 milisecond
WHERE (
duration > 1000
--AND sqlserver.client_hostname <> 'A'
)
),
--adding Module_End. Gives us the various SPs called.
ADD EVENT sqlserver.module_end
(
ACTION (sqlserver.sql_text, sqlserver.tsql_stack, sqlserver.client_app_name,
sqlserver.username, sqlserver.client_hostname, sqlserver.session_nt_username)
WHERE (
duration > 1000000
--note that 1 second duration is 1million, and we still need to match it up via the causality
--AND sqlserver.client_hostname <> 'A'
)
)
-- Add target for capturing the data - XML File
-- You don't need this (pull the ring buffer into temp table),
-- but allows us to capture more events (without allocating more memory to the buffer)
--!!! Remember the files will be left there when done!!!
ADD TARGET package0.asynchronous_file_target(
SET filename='c:\Test\LongRunningQuery.xet', metadatafile='c:\Test\LongRunningQuery.xem'),
-- Add target for capturing the data - Ring Buffer. Can query while live, or just see how chatty it is
ADD TARGET package0.ring_buffer
(SET max_memory = 4096)
WITH (max_dispatch_latency = 1 SECONDS, TRACK_CAUSALITY = ON)
GO
 
 
 
-- Enable Event, aka Turn It On
ALTER EVENT SESSION LongRunningQuery ON SERVER
STATE=START
GO
 

-----------------------------------------------------
--Read the ring buffer to see how often it's firing--
-----------------------------------------------------
-- Basically, make sure the session isn't capturing a ton
-- Has to run while capturing; vanishes when EVENT SESSION is STOPped. (Can ALTER it and drop events to keep it up)
-- Doing it via variable for speed; CTE takes several seconds, as opposed to subsecond.
 
DECLARE	@XMLLongRunning XML
SELECT	@XMLLongRunning = CAST(dt.target_data AS XML)
FROM sys.dm_xe_session_targets dt
JOIN	sys.dm_xe_sessions ds
		ON ds.Address = dt.event_session_address
JOIN	sys.server_event_sessions ss
		ON ds.Name = ss.Name
WHERE dt.target_name = 'ring_buffer'
AND ds.Name = 'LongRunningQuery'
 
select T.N.value('local-name(.)', 'varchar(max)') as Name,
       T.N.value('.', 'varchar(max)') as Value
from @XMLLongRunning.nodes('/*/@*') as T(N) --Mikael Eriksson on StackOverflow


 
/* to get ALLLL the gory details...
SELECT CAST(dt.target_data AS XML) AS xmlLockData, *
FROM sys.dm_xe_session_targets dt
JOIN sys.dm_xe_sessions ds ON ds.Address = dt.event_session_address
JOIN sys.server_event_sessions ss ON ds.Name = ss.Name
WHERE dt.target_name = 'ring_buffer'
AND ds.Name = 'LongRunningQuery'
*/
 
 
 
---------------------
--Stop And Clean Up--
---------------------
 
-- Stop the event
ALTER EVENT SESSION LongRunningQuery ON SERVER
STATE=STOP
GO
 
-- Clean up. Drop the event
DROP EVENT SESSION LongRunningQuery
ON SERVER
GO
 
 
 
 
------------------------------
--Shred XML for easy reading--
------------------------------
 
--pull into temp table for speed and to make sure the ID works right
if object_id('tempdb..#myxml') is not null
DROP TABLE #myxml
CREATE TABLE #myxml (id INT IDENTITY, actual_xml XML)
INSERT INTO #myxml
SELECT CAST(event_data AS XML)
FROM sys.fn_xe_file_target_read_file
('c:\Test\LongRunningQuery*.xet',
'c:\Test\LongRunningQuery*.xem',
NULL, NULL)
 
 
--Now toss into temp table, generically shredded
if object_id('tempdb..#ParsedData') is not null
DROP TABLE #ParsedData
CREATE TABLE #ParsedData (id INT, Actual_Time DATETIME, EventType sysname, ParsedName sysname, NodeValue VARCHAR(MAX))
INSERT INTO #ParsedData --(id, ParsedName, NodeValue)
--doing the DATEADD because @timestamp is stored with timezone detail, if not on UTC off by HOURS.
SELECT id,
DATEADD(MINUTE, DATEPART(TZoffset, SYSDATETIMEOFFSET()), UTC_Time) AS Actual_Time,
EventType,
ParsedName,
NodeValue
FROM (
SELECT id,
A.B.value('@name[1]', 'varchar(128)') AS EventType,
A.B.value('./@timestamp[1]', 'datetime') AS UTC_Time,
X.N.value('local-name(.)', 'varchar(128)') AS NodeName,
X.N.value('../@name[1]', 'varchar(128)') AS ParsedName,
X.N.value('./text()[1]', 'varchar(max)') AS NodeValue
FROM [#myxml]
CROSS APPLY actual_xml.nodes('/*') AS A (B)
CROSS APPLY actual_xml.nodes('//*') AS X (N)
) T
WHERE NodeName = 'value'
--could also use "X.N.value(''./text()[1]'', ''varchar(max)'') is not null" inside
 
--And now use the standard dynamic pivot to shred.
-- Because of the way the pivot works, the fields are alphabetical; not a big deal, but fixable
DECLARE @SQL AS VARCHAR (MAX)
DECLARE @Columns AS VARCHAR (MAX)
SELECT @Columns=
COALESCE(@Columns + ',','') + QUOTENAME(ParsedName)
FROM
(
SELECT DISTINCT ParsedName
FROM #ParsedData
		 --excluded it here, but the tsql_stack can be used to get the exact statement from the plan cache
--see http://blogs.msdn.com/b/extended_events/archive/2010/05/07/making-a-statement-how-to-retrieve-the-t-sql-statement-that-caused-an-event.aspx
WHERE ParsedName <> 'tsql_stack'
) AS B
-- ORDER BY B.ParsedName
SET @SQL='
SELECT Actual_Time, EventType,' + @Columns + ' FROM
(
SELECT id, EventType, Actual_Time, ParsedName, NodeValue FROM
#ParsedData ) AS source
PIVOT
(max(NodeValue) FOR source.ParsedName IN (' + @columns + ')
)AS pvt order by actual_time, attach_activity_id'
EXEC (@sql) 