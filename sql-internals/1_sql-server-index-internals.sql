 --Inspecting the Physical Structure and B-Tree Levels of an Index
SELECT 
      index_depth AS D
    , index_level AS L
    , record_count AS 'Count'
    , page_count AS PgCnt
    , avg_page_space_used_in_percent AS 'PgPercentFull'
    , min_record_size_in_bytes AS 'MinLen'
    , max_record_size_in_bytes AS 'MaxLen'
    , avg_record_size_in_bytes AS 'AvgLen'
FROM sys.dm_db_index_physical_stats
(
      DB_ID ('IndexInternals')                -- Database ID
    , OBJECT_ID ('IndexInternals.dbo.Person')-- Object/Table ID
    , 1                                      -- Index ID
    , NULL                                   -- All partitions
    , 'DETAILED'                             -- Detailed physical analysis
);
GO


-- Inspect index page allocation and the logical page chain
SELECT 
      page_level AS Level                    -- B-tree level of the page
    , allocated_page_file_id AS PageFID     -- File ID where the page is allocated
    , allocated_page_page_id AS PagePID     -- Page ID / page number
    , previous_page_file_id AS PrevPageFID  -- File ID of the previous page
    , previous_page_page_id AS PrevPagPID   -- Page ID of the previous page
    , next_page_file_id AS NextPageFID      -- File ID of the next page
    , next_page_page_id AS NextPagePID      -- Page ID of the next page

FROM sys.dm_db_database_page_allocations
(
      DB_ID('IndexInternals')               -- Database being examined
    , OBJECT_ID('dbo.Person')               -- Person table
    , 2                                     -- Index ID = 2
    , NULL                                  -- All partitions
    , 'DETAILED'                            -- Return detailed page information
)

ORDER BY 
      page_level DESC                       -- Show higher B-tree levels first
    , previous_page_page_id;                -- Then order by previous-page linkage
GO

--Inspecting Index Pages Using DBCC IND --individual pages belonging to a table and its indexes.
CREATE TABLE #DBCCIND
(
    PageFID INT,
    PagePID INT,
    IAMFID INT,
    IAMPID INT,
    ObjectID INT,
    IndexID INT,
    PartitionNumber INT,
    PartitionID BIGINT,
    iam_chain_type VARCHAR(100),
    PageType INT,
    IndexLevel INT,
    NextPageFID INT,
    NextPagePID INT,
    PrevPageFID INT,
    PrevPagePID INT
);

INSERT INTO #DBCCIND
EXEC ('DBCC IND(''IndexInternals'', ''dbo.Person'', 0)');  

select * from #DBCCIND

