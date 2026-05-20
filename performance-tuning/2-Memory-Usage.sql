SELECT TOP(5) [type] AS [ClerkType],
SUM(pages_kb) / 1024 AS [SizeMb]
FROM sys.dm_os_memory_clerks WITH (NOLOCK)
GROUP BY [type]
ORDER BY SUM(pages_kb) DESC

 /*Show Number of sessions currently runng and Requested and Granted memory and if the granted memory is null that means SQL has not granted the memory*/
SELECT session_id, requested_memory_kb / 1024 as RequestedMemMb, 
granted_memory_kb / 1024 as GrantedMemMb, text
FROM sys.dm_exec_query_memory_grants qmg
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
 
/*When target and Total Server Memory is same, then there is no memory pressure*/
SELECT counter_name,
       cntr_value
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Memory Manager'
AND counter_name IN (
    'Memory Grants Pending', --Waiting for SQL to Assign memory
    'Memory Grants Outstanding', -- SQL Granted the memory and it is still working on it.
    'Target Server Memory (KB)', -- Max server memory
    'Total Server Memory (KB)',  -- SQL Consuming Currently
    'Stolen Server Memory (KB)'
);


EXEC DBUtils..sp_whoisactive

EXEC DBUtils..sp_blitzwho
