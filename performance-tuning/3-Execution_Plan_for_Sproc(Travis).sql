SELECT TOP 50
    DB_NAME(st.dbid) [database_name]
  , OBJECT_NAME(st.objectid, st.dbid) AS sproc
  , execution_count
  , [execs_per_minute] = CASE
        WHEN DATEDIFF(MINUTE, qs.creation_time, GETDATE()) <> 0
        THEN CAST(CAST(qs.execution_count AS FLOAT) / CAST(DATEDIFF(MINUTE, qs.creation_time, GETDATE()) AS FLOAT) AS DECIMAL(10, 3))
    END
  , [minutes_between_execs] = CASE
        WHEN DATEDIFF(MINUTE, qs.creation_time, GETDATE()) <> 0
        THEN CONVERT(DECIMAL(12,2),
            CAST(
            DATEDIFF(MINUTE, qs.creation_time, GETDATE()) 
            AS FLOAT) 
            / 
            --CAST(
            qs.execution_count 
            --AS DECIMAL(32,2))
        )
    END
  , [avg_elapsed_time (ms)] = CONVERT(DECIMAL(32, 2), ((total_elapsed_time / 1000.0) / EXECUTION_COUNT))
  , [avg_worker_time (ms)] = CONVERT(DECIMAL(32, 2), ((total_worker_time / 1000.0) / EXECUTION_COUNT))
  , [max_elapsed_time (ms)] = max_elapsed_time / 1000
  , [max_worker_time (ms)] = max_worker_time / 1000
  , [last_worker_time (ms)] = last_worker_time / 1000
  , [avg_reads] = (total_logical_reads / EXECUTION_COUNT) 
  , [avg_phys_reads] = (total_physical_reads / EXECUTION_COUNT) 
  , [avg_writes] = (total_logical_writes / EXECUTION_COUNT) 
  , [avg_cpu_per_minute] = (CONVERT(DECIMAL(32, 2), ((total_worker_time / 1000.0) / EXECUTION_COUNT))) * CASE
                           WHEN DATEDIFF(MINUTE, qs.creation_time, GETDATE()) <> 0
                           THEN CAST(CAST(qs.EXECUTION_COUNT AS FLOAT) / CAST(DATEDIFF(MINUTE, qs.creation_time, GETDATE()) AS FLOAT) AS DECIMAL(10, 3))
                          END
  , last_execution_time
  , qs.creation_time
  , LEFT(SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1, ((CASE qs.statement_end_offset
                                                                  WHEN -1
                                                                  THEN DATALENGTH(st.text)
                                                                  ELSE qs.statement_end_offset
                                                              END - qs.statement_start_offset
                                                             ) / 2
                                                            ) + 1
    ), 10000) AS statement_text
  , [last_elapsed_time (ms)] = last_elapsed_time / 1000
  , qs.max_logical_reads
  , last_logical_reads
  , qs.max_physical_reads
  , last_physical_reads
  , last_logical_writes
  , qs.plan_handle
  , qs.sql_handle
  , CAST(tx.query_plan AS XML) [statement_plan]
FROM sys.dm_exec_query_stats AS qs
OUTER APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
OUTER APPLY sys.dm_exec_text_query_plan(qs.plan_handle, qs.statement_start_offset, qs.statement_end_offset) tx
WHERE 1=1
AND OBJECT_NAME(st.objectid, st.dbid) = '<<Enter the SP Name>>'
 
