# Row not FounD select * from MSpublisher_databases
  EXEC sp_browsereplcmds 
		@xact_seqno_start = '0x0052F2780003E141000A00000000'  
     ,  @xact_seqno_end = '0x0052F2780003E141000A00000000'   
     ,  @publisher_database_id = 20
     ,  @command_id= 2 


# if only one error needs to be skipped, pass all parametera and run it on subscriber on subscribed database
    EXEC  sp_setsubscriptionxactseqno
     @publisher =  N'<Server_Name>'
      ,@publisher_db =  N'DB_Name'
      ,@publication =  N'Publication_Name'
      ,@xact_seqno = 0x00369457001FB2A80026
