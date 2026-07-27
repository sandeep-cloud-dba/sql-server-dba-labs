
EXEC sp_helpindex "Sales.SalesOrderDetail"; --List of Indexes on table

EXEC sp_helpstats 'Sales.SalesOrderDetail', 'ALL'; --Check Information about the Statistics for a table

DBCC SHOW_STATISTICS ("Sales.SalesOrderDetail",IX_SalesOrderDetail_ProductID); --Stats of Index

--Stats information on a table
SELECT  [sch].[name] + '.' + [so].[name] AS [TableName] ,
        [si].[index_id] AS [Index ID] ,
        [ss].[name] AS [Statistic] ,
        STUFF(( SELECT  ', ' + [c].[name]
                FROM    [sys].[stats_columns] [sc]
                        JOIN [sys].[columns] [c]
                         ON [c].[column_id] = [sc].[column_id]
                            AND [c].[object_id] = [sc].[OBJECT_ID]
                WHERE   [sc].[object_id] = [ss].[object_id]
                        AND [sc].[stats_id] = [ss].[stats_id]
                ORDER BY [sc].[stats_column_id]
              FOR
                XML PATH('')
              ), 1, 2, '') AS [ColumnsInStatistic] ,
        [ss].[auto_Created] AS [WasAutoCreated] ,
        [ss].[user_created] AS [WasUserCreated] ,
        [ss].[has_filter] AS [IsFiltered] ,
        [ss].[filter_definition] AS [FilterDefinition] ,
        [ss].[is_temporary] AS [IsTemporary]
FROM    [sys].[stats] [ss]
        JOIN [sys].[objects] AS [so] ON [ss].[object_id] = [so].[object_id]
        JOIN [sys].[schemas] AS [sch] ON [so].[schema_id] = [sch].[schema_id]
        LEFT OUTER JOIN [sys].[indexes] AS [si]
              ON [so].[object_id] = [si].[object_id]
                 AND [ss].[name] = [si].[name]
WHERE   [so].[object_id] = OBJECT_ID(N'Sales.SalesOrderDetail')
ORDER BY [ss].[user_created] ,
        [ss].[auto_created] ,
        [ss].[has_filter];


/*Know your data -  Track Data volumne in table*/
SELECT  OBJECT_NAME([p].[object_id]) AS [Table] ,
        [p].[index_id] AS [Index ID] ,
        [i].[name] AS [Index] ,
        [p].[rows] AS "Number of Rows",
        getdate() AS [Date]
FROM    [sys].[partitions] AS [p]
        JOIN [sys].[indexes] AS [i] ON [p].[object_id] = [i].[object_id]
                                  AND [p].[index_id] = [i].[index_id]
WHERE   [p].[object_id] = OBJECT_ID(N'Sales.SalesOrderDetail');


SELECT  OBJECT_NAME([ips].[object_id]) AS [Table] ,
        [ips].[index_id] AS [Index ID] ,
        [i].[name] AS [Index] ,
        [ips].[record_count] AS [NumberOfRows]
FROM    [sys].[dm_db_index_physical_stats](DB_ID(N'AdventureWorks2022'),
                                     OBJECT_ID(N'Sales.SalesOrderDetail'),
                                       NULL, NULL, 'DETAILED') AS [ips]
        JOIN [sys].[indexes] AS [i] ON [ips].[object_id] = [i].[object_id]
                                  AND [ips].[index_id] = [i].[index_id]
WHERE   [ips].[index_level] = 0;


# Track Modification on table  

/* This  [system_internals_partition_columns], this system view is not documented and is intended for internal use only. 
It may change or be removed in future versions of SQL Server. Use it at your own risk.
The sys.system_internals_partition_columns view returns the number of modifications made to each partition column in the database.
any update, insert or delete operation on a table will increment the modified_count column in this view.
*/
SELECT  OBJECT_NAME([p].[object_id]) AS [Table] ,
        [p].[index_id] AS [Index ID] ,
        [i].[name] AS [Index] ,
        [ipc].[partition_column_id] AS [Index_Column_ID] ,
        [ipc].[modified_count] AS [Modifications]
FROM    [sys].[system_internals_partition_columns] AS [ipc]
        JOIN [sys].[partitions] AS [p]
               ON [ipc].[partition_id] = [p].[partition_id]
        JOIN [sys].[indexes] AS [i]
               ON [p].[object_id] = [i].[object_id]
               AND [p].[index_id] = [i].[index_id]
WHERE   [p].[object_id] = OBJECT_ID(N'Sales.TestSalesOrderDetail');


/*[sys].[dm_db_index_operational_stats] - SQL Server tracks all modifications for a table, regardless of the column modified.
Updates of columns in the key will show up twice if you are aggregating all the leaf level counters, which will inflate the modification counter.
Rebuilding the index will reset the modification counter.
*/
SELECT  OBJECT_NAME([ios].[object_id]) AS [Table] ,
        [ios].[index_id] AS [Index ID] ,
        [i].[name] AS [Index] ,
        [ios].[leaf_insert_count] + [ios].[leaf_update_count]
        + [ios].[leaf_delete_count] + [ios].[leaf_ghost_count]
                                                     AS [Modifications]
FROM    [sys].[dm_db_index_operational_stats](DB_ID(N'AdventureWorks2022'),
                              OBJECT_ID(N'Sales.TestSalesOrderDetail'),
                              NULL, NULL) AS [ios]
        JOIN [sys].[indexes] AS [i] ON [ios].[object_id] = [i].[object_id]
                                  AND [ios].[index_id] = [i].[index_id];

--This reurnts the modifications made to Insert, Update and Delete operations.
SELECT  OBJECT_NAME([ios].[object_id]) AS [Table] ,
        [ios].[index_id] AS [Index ID] ,
        [i].[name] AS [Index] ,
        [ios].[leaf_insert_count] AS [Leaf Level Insert] ,
        [ios].[leaf_update_count] AS [Leaf Level Update] ,
        [ios].[leaf_delete_count] AS [Leaf Level Delete] ,
        [ios].[leaf_ghost_count] AS [Leaf Level Ghost]
FROM    [sys].[dm_db_index_operational_stats](DB_ID(N'AdventureWorks2022'),
                                OBJECT_ID(N'Sales.TestSalesOrderDetail'),
                                NULL, NULL) AS [ios]
        JOIN [sys].[indexes] AS [i] ON [ios].[object_id] = [i].[object_id]
                                    AND [ios].[index_id] = [i].[index_id];

/* [sys].[dm_db_stats_properties] - SQL Server tracks only changes to columns in the key
    update to stats will reset the modification counter. 
*/ 
SELECT  OBJECT_NAME([sp].[object_id]) AS [Table] ,
        [sp].[stats_id] AS [StatisticID] ,
        [s].[name] AS [Statistic] ,
        [sp].[last_updated] AS [LastUpdated] ,
        [sp].[rows] AS [Rows],
        [sp].[rows_sampled] AS [RowsSampled] ,
        [sp].[unfiltered_rows] AS [UnfilteredRows],
        [sp].[modification_counter] AS [Modifications]
FROM   [sys].[dm_db_stats_properties]
               (OBJECT_ID(N'Sales.TestSalesOrderDetail'), 1)
        AS [sp]
        JOIN [sys].[stats] AS [s] ON [sp].[object_id] = [s].[object_id]
                                     AND [sp].[stats_id] = [s].[stats_id];


 --How to start measuing the rate of modification on a table
 -- all statistics, ordered by update_date descending
SELECT  [sch].[name] + '.' + [so].[name] AS [TableName] ,
        [ss].[name] AS [Statistic] ,
        [ss].[auto_Created] AS [WasAutoCreated] ,
        [ss].[user_created] AS [WasUserCreated] ,
        [ss].[has_filter] AS [IsFiltered] ,
        [ss].[filter_definition] AS [FilterDefinition] ,
        [ss].[is_temporary] AS [IsTemporary],
        [sp].[last_updated] AS [StatsLastUpdated], 
        [sp].[rows] AS [RowsInTable], 
        [sp].[rows_sampled] AS [RowsSampled], 
        [sp].[unfiltered_rows] AS [UnfilteredRows],
        [sp].[modification_counter] AS [RowModifications],
        [sp].[steps] AS [HistogramSteps]
FROM    [sys].[stats] [ss]
        JOIN [sys].[objects] [so] ON [ss].[object_id] = [so].[object_id]
        JOIN [sys].[schemas] [sch] ON [so].[schema_id] = [sch].[schema_id]
        OUTER APPLY [sys].[dm_db_stats_properties]
                              ([so].[object_id],[ss].[stats_id]) sp
WHERE   [so].[type] = 'U'
ORDER BY [sp].[last_updated] DESC;


-- Statistics with more than 10% change
SELECT
    [sch].[name] + '.' + [so].[name] AS [TableName],
    [ss].[name] AS [Statistic],
    [ss].[auto_Created] AS [WasAutoCreated],
    [ss].[user_created] AS [WasUserCreated],
    [ss].[has_filter] AS [IsFiltered], 
    [ss].[filter_definition] AS [FilterDefinition], 
    [ss].[is_temporary] AS [IsTemporary],
    [sp].[last_updated] AS [StatsLastUpdated], 
    [sp].[rows] AS [RowsInTable], 
    [sp].[rows_sampled] AS [RowsSampled], 
    [sp].[unfiltered_rows] AS [UnfilteredRows],
    [sp].[modification_counter] AS [RowModifications],
    [sp].[steps] AS [HistogramSteps],
    CAST(100 * [sp].[modification_counter] / [sp].[rows]
                            AS DECIMAL(18,2)) AS [PercentChange]
FROM [sys].[stats] [ss]
JOIN [sys].[objects] [so] ON [ss].[object_id] = [so].[object_id]
JOIN [sys].[schemas] [sch] ON [so].[schema_id] = [sch].[schema_id]
OUTER APPLY [sys].[dm_db_stats_properties]
                    ([so].[object_id], [ss].[stats_id]) sp
WHERE [so].[type] = 'U'
AND CAST(100 * [sp].[modification_counter] / [sp].[rows]
                                        AS DECIMAL(18,2)) >= 10.00
ORDER BY CAST(100 * [sp].[modification_counter] / [sp].[rows]
                                        AS DECIMAL(18,2)) DESC;

