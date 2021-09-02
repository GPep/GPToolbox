--Query to list all execution plans for your Stored Procedures 
SELECT sp.name, qp.query_plan, CP.usecounts, cp.cacheobjtype, cp.size_in_bytes, cp.usecounts, SQLText.text
FROM sys.dm_exec_cached_plans AS CP
CROSS APPLY sys.dm_exec_sql_text( plan_handle)AS SQLText
CROSS APPLY sys.dm_exec_query_plan( plan_handle)AS QP
INNER JOIN sys.procedures AS sp
ON qp.objectId = sp.object_Id
WHERE objtype = 'Proc' and cp.cacheobjtype = 'Compiled Plan'


--Query to List all execution plans for ad-hoc queries (depending on the last time SQL server was restarted, this could be quite big!)
SELECT qp.query_plan, CP.usecounts, cp.cacheobjtype, cp.size_in_bytes, cp.usecounts, SQLText.text
FROM sys.dm_exec_cached_plans AS CP
CROSS APPLY sys.dm_exec_sql_text( plan_handle)AS SQLText
CROSS APPLY sys.dm_exec_query_plan( plan_handle)AS QP
WHERE objtype = 'Adhoc' and cp.cacheobjtype = 'Compiled Plan'

