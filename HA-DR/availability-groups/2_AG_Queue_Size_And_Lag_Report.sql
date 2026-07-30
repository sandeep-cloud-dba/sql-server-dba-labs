SELECT  
    DB_NAME(drs.database_id) AS database_name,
    ar.replica_server_name AS replica_name,
    drs.last_commit_time,
    CAST(DATEDIFF(SECOND, drs.last_commit_time, GETDATE())/3600 AS VARCHAR(10)) 
        + ' hour(s), ' +
    CAST((DATEDIFF(SECOND, drs.last_commit_time, GETDATE())%3600)/60 AS VARCHAR(10)) 
        + ' min, ' +
    CAST(DATEDIFF(SECOND, drs.last_commit_time, GETDATE())%60 AS VARCHAR(10)) 
        + ' sec' AS time_behind_primary,
	drs.log_send_queue_size,
	drs.log_send_rate,
    drs.redo_queue_size,
    drs.redo_rate,
    DATEADD(SECOND,
        CASE 
            WHEN drs.redo_rate = 0 THEN 0
            ELSE drs.redo_queue_size / drs.redo_rate
        END,
        GETDATE()) AS est_completion_time,
    CAST(drs.redo_queue_size / NULLIF(drs.redo_rate,0) AS DECIMAL(10,2)) / 60 AS est_recovery_time_min,
    drs.redo_queue_size / NULLIF(drs.redo_rate,0) AS estimated_recovery_time_sec,
    GETDATE() AS [current_time]
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar
    ON drs.replica_id = ar.replica_id
WHERE drs.is_local = 0
ORDER BY  log_send_queue_size desc;

