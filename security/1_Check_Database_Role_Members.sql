/********************************************************************
 Script Name : 1_Check_Database_Role_Members.sql
 Purpose     : Verify whether user is a member of
                 role across all   databases.
 Author      : DBA Team
 ********************************************************************/
IF OBJECT_ID('tempdb..#RoleMembership') IS NOT NULL
    DROP TABLE #RoleMembership;

CREATE TABLE #RoleMembership
(
    DatabaseName SYSNAME,
    RoleName     SYSNAME NULL,
    MemberName   SYSNAME NULL
);

DECLARE @SQL NVARCHAR(MAX) = '';

SELECT @SQL = @SQL + '
USE ' + QUOTENAME(name) + ';

INSERT INTO #RoleMembership
(
    DatabaseName,
    RoleName,
    MemberName
)
SELECT
    ''' + name + ''',
    r.name,
    m.name
FROM sys.database_role_members rm
INNER JOIN sys.database_principals r
    ON rm.role_principal_id = r.principal_id
INNER JOIN sys.database_principals m
    ON rm.member_principal_id = m.principal_id
WHERE r.name = ''RoleName''
  AND m.name = ''Login(Username)'';
'
FROM sys.databases
--WHERE name IN
--(
--    'DB_Name',
--    ' DB_Name',
--    ' ',
--    ' ',
--    ' ',
--    ' ',
--    ' ',
--    ' '
--);

EXEC(@SQL);

SELECT *
FROM #RoleMembership
ORDER BY DatabaseName;
 
