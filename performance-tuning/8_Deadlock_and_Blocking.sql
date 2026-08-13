/*Deadlock In XML Format*/
SELECT
    DATEADD
    (
        MINUTE,
        DATEDIFF(MINUTE, GETUTCDATE(), GETDATE()),
        CAST(event_data AS XML).value('(event/@timestamp)[1]','datetime2')
    ) AS DeadlockTime,
    CAST(event_data AS XML) AS DeadlockGraph
FROM sys.fn_xe_file_target_read_file
(
    N'system_health*.xel',
    NULL,
    NULL,
    NULL
)
WHERE object_name = 'xml_deadlock_report'
ORDER BY DeadlockTime DESC;
