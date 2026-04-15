
 
0_Enable DB for Publication
 
USE master
EXEC sp_replicationdboption @dbname = 'AdventureWorks2017',
@optname = 'publish',
@value = 'true'
GO

1_Configure_distribution_Publisher_Snapshotfolder
/****** 
Confirm the distribution, change the required parameter as per the environment
The script has 3 steps, execute it one by one and need to change the Parameter
******/
 
DECLARE @distributorserver sysname = N'DPLHA'
DECLARE @distributionDB AS sysname = N'distribution'
--DECLARE @datafolderpath nvarchar(max) 
--DECLARE @logfolderpath nvarchar(max)  
 
use master
exec sp_adddistributor @distributor = @distributorserver --Create distributor using default
 
-- Create a new distribution database using the defaults, including     using Windows Authentication.
exec sp_adddistributiondb @database = @distributionDB,
  --@data_folder = @datafolderpath, 
  --@log_folder = @logfolderpath, 
  --@log_file_size = 2, 
 --@min_distretention = 0, 
 --@max_distretention = 72, 
 --@history_retention = 48,  
 @security_mode = 1
GO
 
--Create the snapshot folder, change the parameter as per the environment
DECLARE @snapshotfolderpath nvarchar(500) = N'\\DPLPR\repldata'
use [distribution] 
if (not exists (select * from sysobjects where name = 'UIProperties' and type = 'U ')) 
create table UIProperties(id int) 
if (exists (select * from ::fn_listextendedproperty('SnapshotFolder', 'user', 'dbo', 'table', 'UIProperties', null, null))) 
EXEC sp_updateextendedproperty N'SnapshotFolder', @snapshotfolderpath, 'user', dbo, 'table', 'UIProperties' 
else 
EXEC sp_addextendedproperty N'SnapshotFolder', @snapshotfolderpath, 'user', dbo, 'table', 'UIProperties'
GO
 
----Enable the Publiser, change the parameter as per the enbironment
DECLARE @Publisher AS sysname = N'DPLHA';
DECLARE @distributionDb AS sysname =  N'distribution'
DECLARE @directory AS nvarchar(500) = N'D:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\ReplData';
 
exec sp_adddistpublisher @publisher = @Publisher, 
 @distribution_db = @distributionDb, 
 @security_mode = 1, 
 @working_directory = @directory, 
 @trusted = N'false', @thirdparty_flag = 0, @publisher_type = N'MSSQLSERVER'
GO
 
2_Enable_Database_For_Publication
-- use the below script to enable database for replication
 
USE <Enter_Db_Name>
 
declare @dbname sysname = '' --Enter the database name to be enabled for publication
-- Enable database for publication
EXEC sp_replicationdboption        @dbname = @dbname, 
@optname = N'publish', 
@value = N'true' 

3_Create_Publication
Use <Db_Name> 
DECLARE @publicationName varchar(100) = N'<Publication_Name>' --Enter the Preffered Publication Name
DECLARE @Description varchar(500) = N'Transactional publication of database ''Sales_T2'' from Publisher ''DPLHA''.' --Replication Description
DECLARE @PushSubsription varchar(100) = N'true' --keep true, if Push Subscription is required
DECLARE @PullSubsription varchar (10) = N'false' --keep True, if Pull subscription is required
 
-- Create publication 
EXEC sp_addpublication 
@publication = @publicationName,   
@description = @Description,  
@sync_method = N'concurrent', 
@retention = 0, 
@allow_push = @PushSubsription, --True -if the requirement is of the Push Subscription, else false
@allow_pull = @PullSubsription, --Tru -if the requirement is of the the Pull subscription, else false
@allow_anonymous = N'true', 
@snapshot_in_defaultfolder = N'true', 
@compress_snapshot = N'false',
@repl_freq = N'continuous', 
@status = N'active', 
@independent_agent = N'true', 
@immediate_sync = N'true', 
@replicate_ddl = 1
 
 
-- Create the snapshot agent of the Publication
EXEC sp_addpublication_snapshot 
  @publication = @publicationName, ---enter the publication name, parameter is defined above, no need to change here
  @frequency_type = 1, 
  @frequency_interval = 1, 
  @frequency_relative_interval = 1, 
  @frequency_recurrence_factor = 0, 
  @frequency_subday = 8, 
  @frequency_subday_interval = 1, 
  @active_start_time_of_day = 0, 
  @active_end_time_of_day = 235959, 
  @active_start_date = 0, 
  @active_end_date = 0, 
  @job_login = NULL, 
  @job_password = NULL, 
  @publisher_security_mode = 1 

3.1_Create_Log_Reader_agent
 
/*  OPTIONAL
Create the log reader agent
If this isn't specified, log reader agent is implicily created 
by the sp_addpublication procedure */
--EXEC sp_addlogreader_agent  @job_login = NULL,  
--                                                        @job_password = NULL,
--                                                        @publisher_security_mode = 1;
--GO
 
4_Add_Article_to_Publication_Start_Snapshot_Agent
Use <dBName>
 
-- Add articles to the publication, this is to be done for all the tables which needs to be relicated
EXEC sp_addarticle 
  @publication = '<Publication_Name>', --Enter the publication Name 
  @article = N'<Table_Name>', --Add the table name which is to be replicated
  @source_owner = N'dbo',  --Enter the schema name (Owner of the table)
  @source_object = N'<Source Table Name>', --Enter the Source table Name
  @type = N'logbased', 
  @description = NULL, .
  @creation_script = NULL, 
  @pre_creation_cmd = N'None', --Drop will drop and recreate the Object 
  @schema_option = 0x000000000803509F, 
  @identityrangemanagementoption = N'manual', --how identity range management is handled for the article
  @destination_table = N'<Destination Table Name>', --Enter the destination table name 
  @destination_owner = N'dbo', --Enter the destination schema name (owner of the table)
  @vertical_partition = N'false', 
  @ins_cmd = N'CALL sp_MSins_PersonAddress', 
  @del_cmd = N'CALL sp_MSdel_PersonAddress', 
  @upd_cmd = N'SCALL sp_MSupd_PersonAddress' 
GO

5_Start_Snapshot_Agent
/*
Start the snapshot agent job so as to generate the snapshot.
This will cause the subscriber to sync immediately (if this option is selected when creating the subscriber)
Get the snapshot agent job name from the distribution database*/
DECLARE @jobname NVARCHAR(200)
SELECT @jobname=name FROM [distribution].[dbo].[MSsnapshot_agents]
WHERE [publication]='<Enter the Publication Name>' AND [publisher_db]='<Enter the Publisher Database>'

Print 'Starting Snapshot Agent ' + @jobname + '....'
/*
Start the snapshot agent to generate the snapshot
The snapshot is picked up and applied to the subscriber by the distribution agent */
EXECUTE msdb.dbo.sp_start_job @job_name=@jobname
 
6_Create_Subscription
use Sales
 
--Add subscription
DECLARE @publication varchar(100) = N'<<Enter the publication database name>>' --Enter the Publication Name
DECLARE @subscriber varchar(100) = N'<<Enter the Subscriber server name>>' --Enter the subscriber Server Name
DECLARE @destination_db varchar(100) = N'<<Enter the destination DB Name>>'  --Enter the Destination DB Name
DECLARE @subscription_type varchar(30) = N'Push'
DECLARE @article varchar(20) = N'all'
 
--@sync_type Check the initial sync type, Automatic Schema and initial data for published tables are transferred to the Subscriber first
--there are other option as well please check on msdn
DECLARE @sync_type varchar(100) = N'automatic'
 
DECLARE @subscriber_db varchar(100) = N'<<Enter the subscriber DB name>>'
DECLARE @subscriber_login varchar(100) = N'<<Replication User>>'
DECLARE @subscriber_password varchar(150) = N'<<Replication Password>>'
 
exec sp_addsubscription 
@publication = @publication, 
@subscriber = @subscriber, 
@destination_db = @destination_db, 
@subscription_type = @subscription_type, 
@article = @article, 
@sync_type = @sync_type, 
@update_mode = N'read only',
@subscriber_type = 0
 
exec sp_addpushsubscription_agent @publication = @publication, 
@subscriber = @subscriber, 
@subscriber_db = @subscriber_db, 
@job_login = null, 
@job_password = null, 
@subscriber_security_mode = 0, 
@subscriber_login = @subscriber_login, 
@subscriber_password = @subscriber_password, 
@frequency_type = 64, 
@frequency_interval = 1, 
@frequency_relative_interval = 1, 
@frequency_recurrence_factor = 0, 
@frequency_subday = 4, 
@frequency_subday_interval = 5, 
@active_start_time_of_day = 0, 
@active_end_time_of_day = 235959, 
@active_start_date = 0, 
@active_end_date = 0, 
@dts_package_location = N'Distributor'

7_Add_Article_to_Existing_Publication
 
--Add atricle in the existing Publication
/*
We can add the article in Publication using GUI or Command but before that we need to follow the below steps
1. immediate sync, Allow_anonymous -  Disable it
2. select immediate_sync,allow_anonymous,* from distribution.dbo.MSpublications
*/
 
Note: While adding article to the existing Publication, keep allow_anonymous and immediate_sync false till the snapshot generation. Once the snapshot is generated and replicated to the subscriber, then set the allow_anonymous and immediate_sync to true
 
--select immediate_sync,allow_anonymous,* from distribution.dbo.MSpublications
 
 
--Step 1 First, change the allow_anonymous property of the publication to FALSE
EXEC sp_changepublication
@publication = N'Sales_T2', --Publication Name
@property = N'allow_anonymous',
@value = N'false' --True=Enable, False=Disable
 
--Step 2 Next, disable Change immediate_sync
EXEC sp_changepublication
@publication = N'Sales_T2', --Publication Name
@property = N'immediate_sync',
@value = N'false' --True=Enable, False=Disable
GO
 
--Step 3 Invalidate the snapshot and Add Article
-- Add articles to the publication, this is to be done for all the tables which needs to be relicated
EXEC sp_addarticle 
  @publication = 'Sales_T2', --Enter the publication Name 
  @article = N'Advit7', --Add the table name which is to be replicated
  @source_owner = N'dbo',  --Enter the schema name (Owner of the table)
  @source_object = N'Advit7', --Enter the Source table Name
  @type = N'logbased', 
  @description = NULL, 
  @creation_script = NULL, 
  @pre_creation_cmd = N'Drop', --Drop will drop and recreate the Object 
  @schema_option = 0x000000000803509F, 
  @identityrangemanagementoption = N'manual', --how identity range management is handled for the article
  @destination_table = N'Advit7', --Enter the destination table name 
  @destination_owner = N'dbo', --Enter the destination schema name (owner of the table)
  @force_invalidate_snapshot=1
GO
 
 
--Step 4 Subscribe the subscription again
	EXEC sp_addsubscription
	@publication = N'Sales_T2',
	@subscriber = N'DPLPR',
	@destination_db = N'Sales_T2'
 
--Step 5 Now, start Snapshot Agent using Replication monitor
--Step 5 Re-enable the disabled properties, first, immediate_sync and then Allow_anonymous options

7.1_Drop_Article_From_Existing_Publication
DECLARE @publication AS sysname  = N'Sales_T2';  
DECLARE @article AS sysname = N'Advit5'; 
DECLARE @subscriber as sysname = N'';
USE Sales  
EXEC sp_dropsubscription
@publication= @publication,
@article = @article,
@subscriber = 'DPLPR'  
-- Drop the transactional article.  
EXEC sp_droparticle   
  @publication = @publication,   
  @article = @article,  
  @force_invalidate_snapshot = 1;  
GO

8_Add_Column_to_Table_In_Publication
EXEC sp_changepublication @publication='Sales_T2'  --Enter the Publication Name
    ,@property='replicate_ddl' 
    ,@value=0  
go 
sp_repladdcolumn @source_object =  '<Table_Name>',  --Table name
                 @column =  'Column_Name',   --Column name, which is to be added to the table
                 @typetext =  'Data_Type' ,  ---Change the datatype
                 @publication_to_add =  'Sales_T2'        --Change the Publication Name                         
go
EXEC sp_changepublication @publication='Sales_T2' --Change the Publication Name        
    ,@property='replicate_ddl' 
    ,@value=1

9_Remove_Replication
--Remove Subscription
DECLARE @publication AS sysname;
DECLARE @subscriber AS sysname;
SET @publication = N'Sales_T2';
SET @subscriber = 'DPLPR';
 
USE Sales
EXEC sp_dropsubscription
@publication = @publication,
@article = N'all',
@subscriber = @subscriber;
GO
 
 
DECLARE @Database AS sysname;
DECLARE @Publication AS sysname;
SET @Database = N'sales';
SET @Publication = N'Sales_T2';
 
-- Remove Publication
USE Sales
EXEC sp_droppublication
@publication = @publication;
 
 
 
-- This script uses sqlcmd scripting variables. They are in the form
-- $(MyVariable). For information about how to use scripting variables  
-- on the command line and in SQL Server Management Studio, see the 
-- "Executing Replication Scripts" section in the topic
-- "Programming Replication Using System Stored Procedures".
 
-- This batch is executed at the Publisher to remove 
-- a pull or push subscription to a transactional publication.
DECLARE @publication AS sysname;
DECLARE @subscriber AS sysname;
SET @publication = N'AdvWorksProductTran';
SET @subscriber = $(SubServer);
 
USE [AdventureWorks2012]
EXEC sp_dropsubscription 
  @publication = @publication, 
  @article = N'all',
  @subscriber = @subscriber;
GO
