/*********************************************************************/
--Script: Captures System Memory Usage
--Works On: 2008, 2008 R2, 2012, 2014, 2016
/*
available_physical_memory_mb: Should be some positive sign based on total physical memory

available_page_file_mb: Should be some positive sign based on your total page file

Percentage_Used: 100% for a long time indicates a memory pressure

system_memory_state_desc: should be Available physical memory is high / steady
*/


/*********************************************************************/

select
      total_physical_memory_kb/1024 AS total_physical_memory_mb,
      available_physical_memory_kb/1024 AS available_physical_memory_mb,
      total_page_file_kb/1024 AS total_page_file_mb,
      available_page_file_kb/1024 AS available_page_file_mb,
      100 - (100 * CAST(available_physical_memory_kb AS DECIMAL(18,3))/CAST(total_physical_memory_kb AS DECIMAL(18,3))) 
      AS 'Percentage_Used',
      system_memory_state_desc
from  sys.dm_os_sys_memory;



/**************************************************************/
-- Script: SQL Server Process Memory Usage
-- Works On: 2008, 2008 R2, 2012, 2014, 2016

/*
physical_memory_in_use: We can’t figure out the exact amount of physical memory using by sqlservr.exe using task manager but this column showcase the actual amount of physical memory using by SQL Server.

locked_page_allocations: If this is > 0 means Locked Pages is enabled for SQL Server which is one of the best practice

available_commit_limit: This indciates the available amount of memory that can be committed by the process sqlservr.exe

page_fault_count: Pages fetching from the page file on the hard disk instead of from physical memory. Consistently high number of hard faults per second represents Memory pressure.
*/
/**************************************************************/
select
      physical_memory_in_use_kb/1048576.0 AS 'physical_memory_in_use (GB)',
      locked_page_allocations_kb/1048576.0 AS 'locked_page_allocations (GB)',
      virtual_address_space_committed_kb/1048576.0 AS 'virtual_address_space_committed (GB)',
      available_commit_limit_kb/1048576.0 AS 'available_commit_limit (GB)',
      page_fault_count as 'page_fault_count'
from  sys.dm_os_process_memory;


/**************************************************************/
--Script: Database Wise Buffer Usage
--Works On: 2008, 2008 R2, 2012, 2014, 2016
/**************************************************************/

DECLARE @total_buffer INT;
SELECT  @total_buffer = cntr_value 
FROM   sys.dm_os_performance_counters
WHERE  RTRIM([object_name]) LIKE '%Buffer Manager' 
       AND counter_name = 'Database Pages';

;WITH DBBuffer AS
(
SELECT  database_id,
        COUNT_BIG(*) AS db_buffer_pages,
        SUM (CAST ([free_space_in_bytes] AS BIGINT)) / (1024 * 1024) AS [MBEmpty]
FROM    sys.dm_os_buffer_descriptors
GROUP BY database_id
)
SELECT
       CASE [database_id] WHEN 32767 THEN 'Resource DB' ELSE DB_NAME([database_id]) END AS 'db_name',
       db_buffer_pages AS 'db_buffer_pages',
       db_buffer_pages / 128 AS 'db_buffer_Used_MB',
       [mbempty] AS 'db_buffer_Free_MB',
       CONVERT(DECIMAL(6,3), db_buffer_pages * 100.0 / @total_buffer) AS 'db_buffer_percent'
FROM   DBBuffer
ORDER BY db_buffer_Used_MB DESC;


/**************************************************************/
--Script: Object Wise Buffer Usage
--Works On: 2008, 2008 R2, 2012, 2014, 2016

/*
Analysis:

From the previous script we can get the top databases using memory. 
This script helps you out in finding the top objects that are using the buffer pool. 
Top objects will tell you the objects which are using the major portion of the buffer pool.
If you find anything suspicious then you can dig into it.
*/
/**************************************************************/

;WITH obj_buffer AS
(
SELECT
       [Object] = o.name,
       [Type] = o.type_desc,
       [Index] = COALESCE(i.name, ''),
       [Index_Type] = i.type_desc,
       p.[object_id],
       p.index_id,
       au.allocation_unit_id
FROM
       sys.partitions AS p
       INNER JOIN sys.allocation_units AS au ON p.hobt_id = au.container_id
       INNER JOIN sys.objects AS o ON p.[object_id] = o.[object_id]
       INNER JOIN sys.indexes AS i ON o.[object_id] = i.[object_id] AND p.index_id = i.index_id
WHERE
       au.[type] IN (1,2,3) AND o.is_ms_shipped = 0
)
SELECT
       obj.[Object],
       obj.[Type],
       obj.[Index],
       obj.Index_Type,
       COUNT_BIG(b.page_id) AS 'buffer_pages',
       COUNT_BIG(b.page_id) / 128 AS 'buffer_mb'
FROM
       obj_buffer obj 
       INNER JOIN sys.dm_os_buffer_descriptors AS b ON obj.allocation_unit_id = b.allocation_unit_id
WHERE
       b.database_id = DB_ID()
GROUP BY
       obj.[Object],
       obj.[Type],
       obj.[Index],
       obj.Index_Type
ORDER BY
       buffer_pages DESC;

GO

/*
It gives as much as memory usage information based on object wise / component wise.
First table gives us the complete details of server and process memory usage details and memory alert indicators.
We can also get memory usage by buffer cache, Service Broker, Temp tables, Procedure Cache, Full Text, XML, 
Memory Pool Manager, Audit Buffer, SQLCLR, Optimizer, SQLUtilities, Connection Pool etc.
*/


DBCC MEMORYSTATUS