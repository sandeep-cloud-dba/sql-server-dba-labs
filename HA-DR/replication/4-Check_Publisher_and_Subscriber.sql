--Check Publisher and it's Subscriber
SELECT DISTINCT
    PRS.srvname AS PublisherServer,
    LRA.publisher_db,
    MP.publication,
    MS.subscriber_db,
    SS.srvname AS SubscriberServer
FROM MSlogreader_agents LRA
INNER JOIN MSsubscriptions MS ON MS.publisher_db = LRA.publisher_db
INNER JOIN MSpublications MP  ON MP.publication_id = MS.publication_id
INNER JOIN dbo.MSreplservers SS ON SS.srvid = MS.subscriber_id
INNER JOIN dbo.MSreplservers PRS ON PRS.srvid = MP.publisher_id
ORDER BY 
    PRS.srvname,
    LRA.publisher_db,
    MP.publication;
