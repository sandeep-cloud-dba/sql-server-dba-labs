/*
    Script:  Drop Login and Database Users from All User Databases
    Target:  SQL Server 2019+
    Author:  OTorres_CCCISIncluded
    Date:    2026-04-07

    Parameters:
        @LoginName   - Server login name / database user name to remove
        @ExecuteMode - 1 = Execute DROP / ALTER AUTHORIZATION
                       0 = Print only (dry-run)

    Behavior:
        Path A: User mapped to server login @LoginName (sid match), types S, U, G.
        Path B: Orphaned user: dp.name = @LoginName, type S or U, no server
                principal for that sid (not dbo/guest/sys/INFORMATION_SCHEMA).

    Notes:
        - Reassigns schema ownership to dbo before DROP USER.
        - Inner batch uses NVARCHAR / N-literals to avoid collation conflicts
          on databases with non-server-default collation (e.g. SSRS DBs).
        - Run with @ExecuteMode = 0 first; review output; then set to 1.
*/

SET NOCOUNT ON;

DECLARE @LoginName   SYSNAME = N'Login_Name';
DECLARE @ExecuteMode BIT     = 0;

DECLARE @SQL    NVARCHAR(MAX) = N'';
DECLARE @DBName SYSNAME;

PRINT N'==========================================================';
PRINT N' Login        : ' + QUOTENAME(@LoginName);
PRINT N' Execute Mode : ' + CASE @ExecuteMode
        WHEN 1 THEN N'EXECUTE (changes WILL be applied)'
        ELSE N'PRINT ONLY (dry-run, no changes)' END;
PRINT N' Run Date     : ' + CONVERT(NVARCHAR(20), SYSDATETIME(), 120);
PRINT N'==========================================================';
PRINT N'';

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT d.[name]
    FROM   sys.databases AS d
    WHERE  d.database_id  > 4
      AND  d.[state]      = 0
      AND  d.is_read_only = 0
    ORDER  BY d.[name];

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
USE ' + QUOTENAME(@DBName) + N';

DECLARE @userName SYSNAME;
DECLARE @path     NVARCHAR(20);

/* Path A: mapped to server login */
IF EXISTS (
    SELECT 1
    FROM   sys.database_principals AS dp
    INNER JOIN sys.server_principals AS sp ON dp.[sid] = sp.[sid]
    WHERE  sp.[name] = @Login
      AND  dp.[type] IN (''S'', ''U'', ''G'')
)
BEGIN
    SET @path = N''MAPPED'';

    SELECT @userName = dp.[name]
    FROM   sys.database_principals AS dp
    INNER JOIN sys.server_principals AS sp ON dp.[sid] = sp.[sid]
    WHERE  sp.[name] = @Login;
END
/* Path B: orphaned user (name match, sid not on server) */
ELSE IF EXISTS (
    SELECT 1
    FROM   sys.database_principals AS dp
    WHERE  dp.[name] = @Login
      AND  dp.[type] IN (''S'', ''U'')
      AND  dp.[name] NOT IN (N''dbo'', N''guest'', N''sys'', N''INFORMATION_SCHEMA'')
      AND  NOT EXISTS (SELECT 1 FROM sys.server_principals AS sp WHERE sp.[sid] = dp.[sid])
)
BEGIN
    SET @path = N''ORPHAN'';
    SET @userName = @Login;
END
ELSE
BEGIN
    PRINT N''  (no mapped or orphaned user found -- skipped)'';
    SET @userName = NULL;
END;

IF @userName IS NOT NULL
BEGIN
    PRINT N''  Path: '' + @path + N'' | User: '' + QUOTENAME(@userName);

    DECLARE @schema   SYSNAME;
    DECLARE @alterSQL NVARCHAR(500);

    DECLARE schema_cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT s.[name]
        FROM   sys.schemas AS s
        INNER JOIN sys.database_principals AS dp ON s.principal_id = dp.principal_id
        WHERE  dp.[name] = @userName;

    OPEN schema_cur;
    FETCH NEXT FROM schema_cur INTO @schema;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @alterSQL = N''ALTER AUTHORIZATION ON SCHEMA::''
                        + QUOTENAME(@schema) + N'' TO [dbo];'';

        IF @Exec = 1
        BEGIN
            EXEC sys.sp_executesql @alterSQL;
            PRINT N''  [EXECUTED] '' + @alterSQL;
        END
        ELSE
            PRINT N''  [PRINT]    '' + @alterSQL;

        FETCH NEXT FROM schema_cur INTO @schema;
    END;

    CLOSE schema_cur;
    DEALLOCATE schema_cur;

    DECLARE @dropUserSQL NVARCHAR(500) = N''DROP USER '' + QUOTENAME(@userName) + N'';'';

    IF @Exec = 1
    BEGIN
        EXEC sys.sp_executesql @dropUserSQL;
        PRINT N''  [EXECUTED] '' + @dropUserSQL;
    END
    ELSE
        PRINT N''  [PRINT]    '' + @dropUserSQL;
END;
';

    PRINT N'----------------------------------------------';
    PRINT N'Database: ' + QUOTENAME(@DBName);
    PRINT N'----------------------------------------------';

    EXEC sys.sp_executesql
        @SQL,
        N'@Login SYSNAME, @Exec BIT',
        @Login = @LoginName,
        @Exec  = @ExecuteMode;

    FETCH NEXT FROM db_cursor INTO @DBName;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

PRINT N'';
PRINT N'==========================================================';
PRINT N' Server Login';
PRINT N'==========================================================';

IF EXISTS (SELECT 1 FROM sys.server_principals AS sp WHERE sp.[name] = @LoginName)
BEGIN
    DECLARE @DropLoginSQL NVARCHAR(500) = N'DROP LOGIN ' + QUOTENAME(@LoginName) + N';';

    IF @ExecuteMode = 1
    BEGIN
        EXEC sys.sp_executesql @DropLoginSQL;
        PRINT N'  [EXECUTED] ' + @DropLoginSQL;
    END
    ELSE
        PRINT N'  [PRINT]    ' + @DropLoginSQL;
END
ELSE
BEGIN
    PRINT N'  Login ' + QUOTENAME(@LoginName) + N' does not exist on this server.';
END;

PRINT N'';
PRINT N'==========================================================';
PRINT N' Completed -- ' + CASE @ExecuteMode
        WHEN 1 THEN N'All commands were EXECUTED.'
        ELSE N'Dry-run finished. Set @ExecuteMode = 1 to apply changes.' END;
PRINT N'==========================================================';

SET NOCOUNT OFF;
GO
