/*sp_whoisactive  -  script to check blocking and it's chain*/
exec sp_whoisactive   @get_outer_command=1
, @output_column_list = '[dd%][session_id][blocking_session_id][blocked_session_count][Wait_info][login_name][host_name][database_name][cpu][used_memory][sql_command][sql_text][wait_info]
						[reads][writes][program_name][collection_time]'
, @find_block_leaders=1,@sort_order = '[blocked_session_count] DESC'

exec sp_whoisactive  @format_output=01,@get_plans=1, @get_additional_info=1 



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
