SELECT TOP(5) [type] AS [ClerkType],
SUM(pages_kb) / 1024 AS [SizeMb]
FROM sys.dm_os_memory_clerks WITH (NOLOCK)
GROUP BY [type]
ORDER BY SUM(pages_kb) DESC

SELECT session_id, requested_memory_kb / 1024 as RequestedMemMb, 
granted_memory_kb / 1024 as GrantedMemMb, text
FROM sys.dm_exec_query_memory_grants qmg
CROSS APPLY sys.dm_exec_sql_text(sql_handle)

SELECT counter_name,
       cntr_value
FROM sys.dm_os_performance_counters
WHERE object_name = 'SQLServer:Memory Manager'
AND counter_name IN (
    'Memory Grants Pending',
    'Memory Grants Outstanding',
    'Target Server Memory (KB)',
    'Total Server Memory (KB)',
    'Stolen Server Memory (KB)'
);