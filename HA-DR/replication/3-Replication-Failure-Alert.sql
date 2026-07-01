DECLARE @html NVARCHAR(MAX);
DECLARE @publisher SYSNAME;
DECLARE @email_subject NVARCHAR(200);
-- Temp table to hold results
IF OBJECT_ID('tempdb..#Errors') IS NOT NULL DROP TABLE #Errors;

SELECT 
    e.time AS Error_Occured_At,
    a.publisher_db,
    a.publication,
    a.subscriber_db,
    e.error_text,
    ROW_NUMBER() OVER (
        PARTITION BY e.error_text 
        ORDER BY e.time DESC
    ) AS rn
INTO #Errors
FROM distribution_Product.dbo.MSrepl_errors e
JOIN distribution_Product.dbo.MSdistribution_history h 
    ON e.id = h.error_id
JOIN distribution_Product.dbo.MSdistribution_agents a 
    ON h.agent_id = a.id
WHERE 
    e.error_code IS NOT NULL and e.error_code !=''
    AND e.time > DATEADD(MINUTE, -20, GETDATE());

-- Get Publisher Server Name (pick top 1 if multiple)
SELECT @publisher = SUBSTRING(name, 1, CHARINDEX('-', name) - 1)
FROM distribution_Product..MSdistribution_agents;

--  Send only if errors exist
IF EXISTS (SELECT 1 FROM #Errors WHERE rn = 1)
BEGIN

    SET @html = '
<html>
<head>
<style>
    body { 
        font-family: Calibri, Arial; 
        font-size: 12px;   
    }

    h2 {
        font-size: 16px;
        margin-bottom: 10px;
    }

    table { 
        border-collapse: collapse; 
        width: 100%; 
        font-size: 11px;    
    }

    th { 
        background-color: #4472C4; 
        color: white; 
        padding: 6px; 
        text-align: left;
        border: 1px solid #000;  
    }

    td { 
        padding: 5px; 
        border: 1px solid #000;  
        vertical-align: top;
    }

    tr:nth-child(even) { 
        background-color: #F2F2F2; 
    }

</style>
</head>
<body>

<h2>Replication Error Report</h2>
<table>
<tr>
    <th>Error Time</th>
    <th>Publisher</th>
    <th>Publisher DB</th>
    <th>Publication</th>
    <th>Subscriber DB</th>
    <th>Error Message</th>
</tr>';

    -- Append rows
    SELECT @html = @html +
        '<tr>' +
        '<td>' + CONVERT(VARCHAR, Error_Occured_At, 120) + '</td>' +
        '<td>' + ISNULL(@publisher,'') + '</td>' +
        '<td>' + ISNULL(publisher_db,'') + '</td>' +
        '<td>' + ISNULL(publication,'') + '</td>' +
        '<td>' + ISNULL(subscriber_db,'') + '</td>' +
        '<td>' + REPLACE(ISNULL(error_text,''), '<', '&lt;') + '</td>' +
        '</tr>'
    FROM #Errors
    WHERE rn = 1;

    -- Close HTML
    SET @html = @html + '
    </table>
    </body>
    </html>';

    -- Send email (Publisher added in subject)
SET @email_subject = 'URGENT: Replication Failure Alerts For - ' + @publisher

EXEC msdb.dbo.sp_send_dbmail
    @profile_name = '<Email_Profile>',
    @recipients = '<Email_ID>',
    @subject = @email_subject,
    @body = @html,
    @body_format = 'HTML';
	END
