/*it does not shows the elapsed time of the session, but other useful infos*/
SELECT 
    s.session_id,
    r.status,
    r.cpu_time,
    r.logical_reads,
    SUBSTRING(
        st.text, 
        (r.statement_start_offset/2) + 1,
        ((CASE r.statement_end_offset 
              WHEN -1 THEN DATALENGTH(st.text)
              ELSE r.statement_end_offset 
          END - r.statement_start_offset)/2) + 1
    ) AS StatementText,
    OBJECT_NAME(st.objectid, r.database_id) AS StoredProcedureName,  -- 👈 Added line
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    r.blocking_session_id,
    r.granted_query_memory AS buffer, -- memory grant in pages
    s.login_name,
    qp.query_plan,
    st.text AS FullSQLText
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s 
    ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) st
CROSS APPLY sys.dm_exec_query_plan(r.plan_handle) qp
WHERE s.session_id <> @@SPID  -- exclude current session
ORDER BY r.cpu_time DESC;



/*it shows the elapsed time of the session*/
SELECT 
    r.session_id,
    r.status,
    r.cpu_time,

    -- Convert milliseconds to HH:MM:SS
    RIGHT('00' + CAST((r.total_elapsed_time / 3600000) AS VARCHAR), 2) + ':' +
    RIGHT('00' + CAST((r.total_elapsed_time % 3600000) / 60000 AS VARCHAR), 2) + ':' +
    RIGHT('00' + CAST((r.total_elapsed_time % 60000) / 1000 AS VARCHAR), 2) 
    AS Elapsed,

    r.logical_reads AS LogicalReads,

    SUBSTRING(t.text, 
        (r.statement_start_offset/2) + 1,
        ((CASE r.statement_end_offset
            WHEN -1 THEN DATALENGTH(t.text)
            ELSE r.statement_end_offset
         END - r.statement_start_offset)/2) + 1
    ) AS statement,

    (r.logical_reads * 8) AS buffer,

    s.login_name,

    qp.query_plan AS InFlightPlan

FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s 
    ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) qp

WHERE r.session_id <> @@SPID
ORDER BY r.cpu_time DESC;
