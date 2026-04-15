EXEC sp_changepublication 
  @publication = 'Enter_Publication_Name', 
  @property = N'allow_anonymous', 
  @value = 'false'
GO

EXEC sp_changepublication 
  @publication = 'Enter_Publication_Name', 
  @property = N'immediate_sync', 
  @value = 'false'
GO

--Dropping Article
use [Database_Name]
go
exec sp_dropsubscription @publication = '<Enter_Publication_Name>', @subscriber = '<Enter_SubsCriber_Name>', @article = 'Enter_Article_Name'


use [Database_Name]
go
exec sp_droparticle @publication = 'Enter_Publication_Name', @article = 'Enter_Article_Name'


--Adding Article

EXEC sp_addarticle @publication = 'RP_FEED_TO_NONPROD_NONGEICO_RP_FEED_CT',
                   @source_owner = 'Staging',
                   @article = 'IHCFA_EBill_CMS_Batch',
                   @source_object = 'IHCFA_EBill_CMS_Batch',
                   @destination_table = 'IHCFA_EBill_CMS_Batch';

--Refresh the subscription(s) by running the below script on publisher 

EXEC sp_refreshsubscriptions @publication = 'RP_FEED_TO_NONPROD_NONGEICO_RP_FEED_CT';


--Enable Parameters
EXEC sp_changepublication @publication = 'RP_FEED_TO_NONPROD_NONGEICO_RP_FEED_CT',
                          @property = N'immediate_sync',
                          @value = 'true';
GO
EXEC sp_changepublication @publication = 'RP_FEED_TO_NONPROD_NONGEICO_RP_FEED_CT',
                          @property = N'allow_anonymous',
                          @value = 'true';
GO


-------Unsubscribe article for Subscriber
DECLARE @publication AS sysname;
DECLARE @subscriber AS sysname;
SET @publication = N'DEN1_WORKFLOW2GEICO_RP_FEED';
SET @subscriber = 'AIS-UATDB01';

USE DEN1_WORKFLOW
EXEC sp_dropsubscription 
  @publication = @publication, 
  @article = N'DocRouting',
  @subscriber = @subscriber;
GO




-------Add article with specific column name in replication

EXEC sp_addarticle @publication = 'RP_FEED_TO_NONPROD_NONGEICO_RP_FEED_CT',
                   @source_owner = 'dbo',
                   @article = 'IES_Claim',
                   @source_object = 'IES_Claim',
                   @destination_table = 'claim',
                   @vertical_partition = 'true'   ---this parameter needs to be true to add specific column in replication

 EXEC sp_articlecolumn 
    @publication = 'RP_FEED_TO_NONPROD_NONGEICO_RP_FEED_CT', 
    @article = 'IES_Claim', 
    @column = N'ClaimID'
    @operation =N'add' --if you do not pass this parameter, default is add, will add column else drop




---Check count in Publication
select mp.Publication, COUNT(ma.article) as CountofName From MSArticles ma
INNER JOIN MSPublications mp on ma.publication_id = mp.publication_id
GROUP BY mp.Publication

