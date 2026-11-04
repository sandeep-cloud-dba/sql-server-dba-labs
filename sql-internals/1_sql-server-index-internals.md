
# Nonclustered B-Tree Indexes
    1. All indexes have:
       - Leaf level
       - One or more non-leaf levels
    
    2. Clustered index:
       - Leaf level = actual table data
    
    3. Nonclustered index:
       - Leaf level = separate structure
       - Contains NCI key columns
       - Included columns, if defined
       - Row locator/bookmark
    
    4. Row locator:
       - Clustered table → clustering key → Key Lookup
       - Heap → RID (FileID:PageID:SlotNumber) → RID Lookup
    
    5. An unfiltered NCI normally has one row per base-table row.
       Filtered indexes contain only rows satisfying the filter.
    
    6. NCI can be used to:
       - Locate rows in the base table
       - Answer the query directly
    
    7. Covering Index:
       - NCI contains every column required by the query
       - No lookup required
    
    8. If query requires columns not present in NCI:
       NCI → Row Locator → Key/RID Lookup → Base Table
    
    9. NCI does not change the organization of the base table.
    
    10. Base table structure affects NCI:
        Heap → RID stored as locator
        Clustered → Clustering key stored as locator
    
    11. Therefore:
        NCI depends on the base table's structure,
        but NCI does not determine the base table's structure.
  
        A nonclustered index is a separate B-tree whose leaf contains the indexed data plus a locator to the base row; that locator is a RID for a heap or the clustering key for a clustered table.

# Constraints and Indexes
  
    1. PRIMARY KEY and UNIQUE are constraints.
       SQL Server uses indexes to physically enforce their rules.
    
    2. PRIMARY KEY:
       - All participating columns are NOT NULL.
       - Values must be unique.
       - SQL Server creates a UNIQUE index.
       - Default index type = UNIQUE CLUSTERED (if not specified).
    
    3. UNIQUE constraint:
       - NULLs are allowed.
       - Values must satisfy uniqueness.
       - SQL Server creates a UNIQUE index.
       - Default index type = UNIQUE NONCLUSTERED.
    
    4. PRIMARY KEY does NOT have to be clustered.
       PRIMARY KEY NONCLUSTERED can be explicitly specified.
    
    5. Constraint-backed indexes and manually created indexes
       have the same underlying index structure.
    
    6. Constraint-backed indexes cannot use index features such
       as INCLUDE or FILTER in the same way manually created
       indexes can.
    
    7. A UNIQUE index can be referenced by a FOREIGN KEY if it
       is suitable; a filtered unique index cannot be used for
       this purpose.
    
    8. Index created to support a constraint has the same name
       as the constraint.
    
    9. Query Optimizer cares about the presence/properties of
       the unique index, not whether it was created directly
       or created to support a constraint.

        Constraint = rule you want to enforce.
        Index = physical structure SQL Server uses to enforce it and/or access the data efficiently.
    
    10. Uniqueness provides useful cardinality information to
        the optimizer because a unique predicate can return
        at most one row.

        Constraint = rule you want to enforce.
        Index = physical structure SQL Server uses to enforce it and/or access the data efficiently.

# CREATE INDEX Options
    1. IGNORE_DUP_KEY
    
    - Applies to UNIQUE indexes.
    - Does NOT allow duplicate values.
    - Controls what happens when a duplicate is encountered
      during a multi-row INSERT.
    - With IGNORE_DUP_KEY = ON:
        - Duplicate row is discarded.
        - Other nonduplicate rows can be inserted.
    - Without it:
        - Duplicate key violation causes the statement to abort.
    
    Key idea:
    IGNORE_DUP_KEY changes duplicate-handling behavior,
    not the uniqueness property of the index.
    
    
    2. STATISTICS_NORECOMPUTE
    
    - Controls automatic statistics updates for an index/statistic.
    - Normally AUTO_UPDATE_STATISTICS updates statistics when needed.
    - STATISTICS_NORECOMPUTE can prevent automatic updates
      for a specific index/statistic.
    - Stale statistics can lead to inaccurate cardinality estimates
      and potentially less-optimal execution plans.
    - Statistics can be updated manually using:
        UPDATE STATISTICS
        sp_updatestats
    
    
    3. MAXDOP
    
    - Controls the maximum degree of parallelism for index creation.
    - MAXDOP specifies the maximum number of processors/workers,
      not necessarily the number actually used.
    - SQL Server can choose fewer processors depending on system load.
    - Parallel index creation can improve index build performance.
    - Parallel workers can build separate portions of the index,
      so actual page usage may differ from theoretical calculations.
    
    
    4. Index Placement
    
    CREATE INDEX supports:
    
    ON filegroup_name
    
    or
    
    ON partition_scheme_name(column_name)
    
    - Determines where the index is stored.
    - An index can be placed on a specific filegroup.
    - An index can also be partitioned using a partition scheme.
    - If placement isn't specified, default filegroup behavior applies.

# Physical Structure of B-Tree Index Pages

    - SQL Server pages are fixed at 8 KB (8,192 bytes).
    - Index pages have a 96-byte page header.
    - An offset/slot array exists at the end of the page and uses 2 bytes per row.
    - A nonclustered index can use:
      - IN_ROW_DATA
      - ROW_OVERFLOW_DATA
      - LOB_DATA
    
    ### Index Row Structure
    
    Index rows are similar to data rows but have some differences.
    
    Index row:
    1. TagA / Status Bits A
    2. Fixed-length data (Fdata)
    3. Ncol
    4. NULL bitmap (only when applicable)
    5. VarCount (if variable-length columns exist)
    6. VarOffset (if variable-length columns exist)
    7. VarData
    
    Important differences:
    - Index rows cannot preserve SPARSE storage representation.
    - Nonunique clustered indexes can use a hidden uniquifier for duplicate clustering-key values.
    - Index rows don't use the Fsize row-header field.
    - Instead, pminlen in the page header is used to determine the end of fixed-length data.
    - Ncol and NULL bitmap are present in index rows when nullable columns require them.

# Clustered Index Physical Structure
    ### Clustered Index Leaf
    
    - The leaf level of a clustered index is the actual table data.
    - Unlike a nonclustered index, the clustered leaf does not contain a separate row locator to the base table.
    - A clustered index can be nonunique.
    - When duplicate clustering-key values exist, SQL Server uses a hidden 4-byte uniquifier to distinguish rows internally.
    
    ### Non-leaf Clustered Index Rows
    
    Each non-leaf row contains:
    
    - Index key
    - 6-byte child-page pointer
      - 2 bytes = FileID
      - 4 bytes = PageID
    - Row overhead
    
    The 6-byte pointer identifies a page, so no slot number is required.
    
    ### B-tree Navigation
    
    Each non-leaf level contains an entry for every page at the level below.
    
    Example:
    
    4,000 leaf pages
    → 4,000 entries at Level 1
    → 7 Level-1 pages
    → 7 entries at Level 2
    → 1 root page
    
    The key in a non-leaf entry represents the first possible key value for the referenced child page.
    
    It is a navigation boundary, not necessarily the exact current first row on the page.
    
    ### Clustered Index Seek
    
    For:
    
    WHERE EmployeeID = 27682
    
    SQL Server:
    
    1. Starts at the root.
    2. Uses the clustering key to choose the appropriate child page.
    3. Continues through intermediate levels.
    4. Reaches the leaf/data page.
    5. Finds the requested row.
    
    Example:



# Clustering Key Dependency

    ## 1. Importance of Clustering Key Selection
    
    Choosing a clustered index is not just about improving the performance of one query.
    
    The clustering key becomes a dependency of every nonclustered index because SQL Server uses it as the row locator to identify rows in the clustered index.
    
    A good clustering key should generally be:
    
    * **Unique:** Uniqueness avoids the need for an internal uniquifier.
    * **Narrow:** Reduces storage overhead in every nonclustered index.
    * **Stable:** Avoids frequent updates to the clustering key.
    * **Increasing (where appropriate):** Can reduce random page splits for insert-heavy workloads.
    
    The best clustering key ultimately depends on the workload.
    
    ## 2. Clustered Index and Data Organization
    
    When a clustered index is created, the existing table data becomes the leaf level of the clustered index.
    
    * The leaf level contains the actual table data.
    * Rows are logically ordered according to the clustering key.
    * Leaf pages are maintained through a doubly linked page chain.
    * The page chain maintains logical order, not necessarily physical disk contiguity.
    
    A table can have only one clustered index because it can have only one clustered ordering of its data.
    
    ### Example: Person.Person
    
    ```text
    PK_Person_BusinessEntityID
               |
               v
         Clustered Index
               |
               v
    BusinessEntityID = Clustering Key
    ```
    
    ## 3. Nonclustered Index Dependency on Clustering Key
    
    A nonclustered index is a separate B-tree structure.
    
    Its leaf level contains:
    
    1. Defined nonclustered index key columns.
    2. Included columns, if any.
    3. Row locator.
    
    The row locator depends on the underlying table structure:
    
    | Table Structure | Row Locator    | Lookup Operator |
    | --------------- | -------------- | --------------- |
    | Clustered table | Clustering key | Key Lookup      |
    | Heap            | RID            | RID Lookup      |
    
    ### Conceptual NCI Structure
    
    ```text
    Nonclustered Index Leaf
    |
    |-- Defined index key columns
    |
    |-- Included columns (if any)
    |
    |-- Row locator
          |
          |-- Clustering key (clustered table)
          |
          |-- RID (heap)
    ```
    
    ## 4. Covering Index and Key Lookup
    
    If a query requires only columns available in the nonclustered index, SQL Server can return the results directly from the NCI without accessing the clustered index.
    
    This is called a **Covering Index**.
    
    Important points:
    
    * The clustering key is already available in the NCI as the row locator.
    * It can be returned without performing a Key Lookup.
    * If a required column is missing from the NCI, SQL Server may perform a Key Lookup to retrieve it from the clustered index.
    * The optimizer decides whether the lookup is cost-effective.
    
    ### Example
    
    ```sql
    CREATE CLUSTERED INDEX CX_Employee
    ON Employee(EmployeeID);
    
    CREATE NONCLUSTERED INDEX IX_Employee_LastName
    ON Employee(LastName);
    ```
    
    Query:
    
    ```sql
    SELECT EmployeeID, LastName
    FROM Employee
    WHERE LastName = 'Smith';
    ```
    
    Both requested columns are available in the NCI.
    
    Therefore, SQL Server can satisfy the query without a Key Lookup.
    
    ## 5. Nonunique Clustered Index and Uniquifier
    
    The nonclustered index key does not have to be unique.
    
    However, the row locator must uniquely identify the corresponding base-table row.
    
    If a clustered index is nonunique and duplicate clustering-key values exist, SQL Server adds a hidden 4-byte uniquifier when necessary.
    
    Conceptually:
    
    ```text
    Effective Clustering Key
              =
    Clustering Key + Uniquifier
    ```
    
    This allows SQL Server to distinguish rows having duplicate clustering-key values.
    
    ## 6. Why Clustering Key Width Matters
    
    All columns making up the clustering key are carried into each nonclustered index as the row locator.
    
    Therefore:
    
    * A wider clustering key increases NCI storage requirements.
    * More storage can increase memory requirements.
    * Larger indexes can require more page reads.
    * Index maintenance can become more expensive.
    
    A narrow clustering key can reduce overhead across all nonclustered indexes.
    
    ## Key Takeaway
    
    The clustering key is not just responsible for organizing the clustered index. It also acts as the row locator in every nonclustered index on that clustered table.
    
    Therefore, clustering-key selection affects the storage, maintenance and performance characteristics of the entire index architecture.
    
        Root Page 234
        → Intermediate Page 235
        → Leaf/Data Page 1616
        → EmployeeID 27682


# Nonclustered Index on a Heap
    When a nonclustered index is created on a heap, its leaf-level rows contain:
    
    1. Defined nonclustered index key columns.
    2. RID (Row Identifier) as the row locator.
    
    ### RID Structure
    
    A RID uniquely identifies a physical row in a heap.
    
    * FileID: 2 bytes
    * PageID: 4 bytes
    * SlotNumber: 2 bytes
    * Total: 8 bytes
    
    ### Example
    
    ```sql
    CREATE NONCLUSTERED INDEX IX_EmployeeHeap_EmployeeID
    ON EmployeeHeap(EmployeeID);
    ```
    
    Conceptual leaf structure:
    
    ```text
    Nonclustered Index Leaf
    |
    |-- EmployeeID (Index Key)
    |
    |-- RID (Row Locator)
          |
          |-- FileID
          |-- PageID
          |-- SlotNumber
    ```
    
    ### Row Lookup Process
    
    1. SQL Server searches the nonclustered index.
    2. Finds the matching index key.
    3. Retrieves the corresponding RID.
    4. Uses the RID to locate the heap data page and slot.
    5. Retrieves the actual data row.
    
    ### Important
    
    * Nonclustered index on a heap uses RID as the row locator.
    * Nonclustered index on a clustered table uses the clustering key as the row locator.
    * A lookup from an NCI to a heap is performed using a RID Lookup operator when the execution plan requires retrieving missing columns.
    
    ### Physical Row-Size Example
    
    For an index on EmployeeID:
    
    * EmployeeID = 4 bytes
    * RID = 8 bytes
    * Row overhead = 1 byte
    
    Total = 13 bytes.
    
    ````
    
    ---
    
    ### Quick knowledge check
    
    One question before we move further:
    
    Suppose we create a nonclustered index on a heap using `EmployeeID`.
    
    ```sql
    CREATE NONCLUSTERED INDEX IX_EmployeeHeap_EmployeeID
    ON EmployeeHeap(EmployeeID);
    ````
    
    **What happens if we physically move a heap row to another page?**
    
    Think about what happens to its RID and the corresponding nonclustered index entry.

    Forwarded record: When an update makes a heap row too large for its original page, SQL Server may move the row and leave a forwarding record at the original location. 
    The RID in the NCI can continue pointing to the original location, which forwards SQL Server to the new location.
    Other row movement: When SQL Server relocates a row without retaining a forwarding record, the affected nonclustered index row locator must be maintained.
    
    We'll study forwarded records separately.
    
    Key takeaway: A RID identifies a physical location, not a permanent logical identity. This is an important difference between heap and clustered-table row locators.


# Nonclustered Index on a Clustered Table

    When a nonclustered index is created on a clustered table, its leaf-level rows contain:
    
    1. Defined nonclustered index key columns.
    2. Clustering key columns as the row locator.
    3. Included columns, if any.
    
    ### Example
    
    Clustered Index:
    
    ```sql
    CREATE UNIQUE CLUSTERED INDEX CX_Employee
    ON Employee(EmployeeID);
    ```
    
    Nonclustered Index:
    
    ```sql
    CREATE UNIQUE NONCLUSTERED INDEX IX_Employee_SSN
    ON Employee(SSN);
    ```
    
    Conceptual NCI leaf structure:
    
    ```text
    Nonclustered Index Leaf
    |
    |-- SSN (NCI Key)
    |
    |-- EmployeeID (Clustering Key / Row Locator)
    ```
    
    ### Key Lookup Process
    
    1. SQL Server searches the NCI using the index key.
    2. Retrieves the clustering key from the NCI.
    3. Uses the clustering key to locate the row in the clustered index.
    4. Retrieves any required columns missing from the NCI.
    
    ### Important Points
    
    * The clustering key is implicitly available in every NCI on a clustered table as its row locator.
    * If the NCI key and clustering key share columns, SQL Server stores common columns only once.
    * A wider clustering key increases the storage requirements of nonclustered indexes.
    * If all required query columns are available in the NCI, SQL Server can avoid a Key Lookup.


# Unique vs Nonunique Nonclustered Indexes on a Clustered Table

    When a nonclustered index is created on a clustered table, SQL Server uses the clustering key as the row locator.
    
    However, how the clustering key is stored depends on whether the NCI is UNIQUE or NONUNIQUE.
    
    ## 1. Nonunique Nonclustered Index
    
    Example:
    
    ```sql
    CREATE NONCLUSTERED INDEX IX_Employee_LastName
    ON Employee(LastName);
    ```
    
    Assume the clustered index is on EmployeeID.
    
    Conceptually, the NCI leaf contains:
    
    ```text
    LastName (key)       -- Explicit NCI key
    EmployeeID (key)     -- Clustering key
    ```
    
    EmployeeID is added to the effective NCI key to uniquely identify index entries.
    
    ## 2. Unique Nonclustered Index
    
    Example:
    
    ```sql
    CREATE UNIQUE NONCLUSTERED INDEX IX_Employee_SSN
    ON Employee(SSN);
    ```
    
    Assume the clustered index is on EmployeeID.
    
    Conceptually, the NCI leaf contains:
    
    ```text
    SSN (key)       -- Explicit unique NCI key
    EmployeeID      -- Clustering key / Row Locator
    ```
    
    SSN is already unique, so EmployeeID does not need to become part of the NCI key.
    
    However, EmployeeID is still required to locate the corresponding row in the clustered index.
    
    ## 3. How to Identify Using DBCC PAGE
    
    Inspect the leaf-level page of each NCI using:
    
    ```sql
    DBCC TRACEON(3604);
    GO
    
    DBCC PAGE (IndexInternals, 1, <PageID>, 3);
    GO
    ```
    
    Interpret the output:
    
    **Nonunique NCI:**
    
    ```text
    LastName (key)
    EmployeeID (key)
    ```
    
    Both participate in the effective NCI key.
    
    **Unique NCI:**
    
    ```text
    SSN (key)
    EmployeeID
    ```
    
    EmployeeID is present as the row locator, not as an additional NCI key column.
    
    ## 4. Comparison
    
    | Property             | Nonunique NCI             | Unique NCI  |
    | -------------------- | ------------------------- | ----------- |
    | Explicit NCI key     | LastName                  | SSN         |
    | Clustering key       | EmployeeID                | EmployeeID  |
    | Clustering key role  | Part of effective NCI key | Row locator |
    | DBCC PAGE indication | EmployeeID (key)          | EmployeeID  |
    
    Note: If a clustering-key column is already present in the NCI key, SQL Server stores it only once.
    
    ## Key Takeaway
    
    * Nonunique NCI: Missing clustering-key columns become part of the effective NCI key.
    * Unique NCI: Missing clustering-key columns are stored as row locators at the leaf level.
    * The clustering key is required in both cases to identify the corresponding clustered row.

# Nonclustered Indexes with Included Columns (INCLUDE)

    ## 1. Purpose
    
    The INCLUDE clause allows additional columns to be stored at the leaf level of a nonclustered index without making them part of the index key.
    
    It is useful for creating covering indexes and eliminating Key Lookups.
    
    ## 2. Example
    
    ```sql
    CREATE NONCLUSTERED INDEX IX_Employee_LastName
    ON Employee(LastName)
    INCLUDE (FirstName, SSN);
    ```
    
    ## 3. Physical Structure
    
    Assuming EmployeeID is the clustering key:
    
    ```text
    NCI Leaf Level
    |
    |-- LastName       (Index Key)
    |-- EmployeeID     (Clustering Key / Row Locator)
    |-- FirstName      (Included Column)
    |-- SSN            (Included Column)
    ```
    
    ## 4. Important Points
    
    * Index key columns participate in the B-tree's sort order.
    * Included columns exist only at the leaf level.
    * Included columns do not participate in index key ordering.
    * Included columns do not count towards the index key column limit.
    * Included columns can help eliminate Key Lookups.
    * Adding included columns increases leaf-level storage requirements.

     ## Index Key Limitations
        | Limitation                  | SQL Server 2014 and earlier | SQL Server 2016 and later |
        | --------------------------- | --------------------------: | ------------------------: |
        | Clustered index key size    |                   900 bytes |                 900 bytes |
        | Nonclustered index key size |                   900 bytes |               1,700 bytes |
        | Maximum key columns         |                          16 |                        32 |
        | Maximum included columns    |                       1,023 |                     1,023 |

    ## 5. Covering Index
    
    A covering index contains all columns required by a query.
    
    SQL Server can retrieve the required information directly from the nonclustered index without accessing the clustered index.
    
    ### Key Takeaway
    
    Use index key columns for searching, sorting and navigation.
    
    Use INCLUDE columns to cover additional query requirements without expanding the index key.


# Filtered Nonclustered Indexes

    ## 1. What is a Filtered Index?
    
    A filtered index is a nonclustered index that contains entries only for rows satisfying a specified filter predicate.
    
    By default, a nonclustered index contains an index entry for every row in the table.
    
    A filtered index reduces the number of index entries by indexing only the rows matching the filter condition.
    
    ### Syntax
    
    ```sql
    CREATE NONCLUSTERED INDEX IX_Employee_SSN
    ON dbo.Employee (SSN)
    WHERE SSN IS NOT NULL;
    ```
    
    ## 2. Benefits of Filtered Indexes
    
    * Reduces index size by indexing only selected rows.
    * Reduces storage requirements.
    * Can reduce index maintenance overhead.
    * Can improve query performance when queries access only the filtered subset.
    * Supports enforcing uniqueness for a selected subset of rows.
    
    ## 3. Important Use Cases
    
    ### Use Case 1: Columns Containing Mostly NULL Values
    
    When a column contains mostly NULL values and queries retrieve only non-NULL rows, a filtered index can be useful.
    
    ```sql
    CREATE NONCLUSTERED INDEX IX_Employee_SSN_NotNull
    ON dbo.Employee (SSN)
    WHERE SSN IS NOT NULL;
    ```
    
    This index contains entries only for rows where SSN is NOT NULL.
    
    It can be particularly useful with SPARSE columns.
    
    ### Use Case 2: Enforcing Uniqueness for Selected Rows
    
    Requirement:
    
    * Multiple rows can have NULL SSN values.
    * Every non-NULL SSN must be unique.
    
    ```sql
    CREATE UNIQUE NONCLUSTERED INDEX UX_Employee_SSN_NotNull
    ON dbo.Employee (SSN)
    WHERE SSN IS NOT NULL;
    ```
    
    A filtered unique index:
    
    * Allows multiple NULL values because those rows are excluded.
    * Enforces uniqueness for all non-NULL SSN values.
    
    ### Use Case 3: Indexing a Specific Data Range
    
    If queries frequently retrieve a specific date range, a filtered index can focus on that subset.
    
    Example: Q4 2011 sales.
    
    ```sql
    CREATE NONCLUSTERED INDEX IX_Sales_Q4_2011
    ON dbo.Sales (SalesDate)
    WHERE SalesDate >= '20111001'
      AND SalesDate < '20120101';
    ```
    
    Only rows matching the date filter are included in the index.
    
    ## 4. Important Points
    
    * Filtered indexes are nonclustered indexes.
    * The leaf level contains entries only for rows matching the filter predicate.
    * The filter column does not necessarily need to be an index key or included column.
    * A filtered index can be UNIQUE.
    * Filtered indexes can reduce storage and maintenance overhead.
    * The query predicate must be compatible with the filter definition for SQL Server to use the index.
    * A filtered index is most useful when queries frequently access a relatively small subset of table rows.
    
    ## 5. Key Takeaway
    
    A regular nonclustered index indexes the entire table.
    
    A filtered nonclustered index indexes only rows matching a specified predicate.
    
    Use filtered indexes when queries repeatedly access a specific subset of data rather than the entire table.

# Indexes on Computed Columns and Indexed Views

    ## 1. Logical vs. Physical Data
    
    Without indexes:
    
    * A normal computed column is calculated when accessed, unless marked `PERSISTED`.
    * A normal view stores only its SELECT definition, not the result data.
    
    Creating indexes can physically materialize these logical values.
    
    | Object          | Without index            | With index                            |
    | --------------- | ------------------------ | ------------------------------------- |
    | Computed column | Calculated when accessed | Computed value stored in index        |
    | View            | Stores SELECT definition | View result stored in clustered index |
    
    **Important:** An index on a non-persisted computed column stores the computed value in the index, but not in the base table.
    
    ---
    
    ## 2. Prerequisites for Indexing
    
    SQL Server requires three categories of conditions:
    
    1. Required session-level SET options.
    2. Restrictions on functions used in expressions.
    3. Requirements on underlying tables (indexed views only).
    
    ## 3. Required SET Options
    
    | SET option              | Required value |
    | ----------------------- | -------------- |
    | CONCAT_NULL_YIELDS_NULL | ON             |
    | QUOTED_IDENTIFIER       | ON             |
    | ANSI_NULLS              | ON             |
    | ANSI_PADDING            | ON             |
    | ANSI_WARNINGS           | ON             |
    | NUMERIC_ROUNDABORT      | OFF            |
    | ARITHABORT              | ON             |
    
    All options must be ON except NUMERIC_ROUNDABORT.
    
    Incorrect settings can result in:
    
    * Index creation failure.
    * Data modification failure.
    * Indexed view or computed-column index being ignored during SELECT queries.
    
    ### Checking SET Options
    
    ```sql
    SELECT
        SESSIONPROPERTY('ANSI_NULLS') AS ANSI_NULLS,
        SESSIONPROPERTY('ANSI_PADDING') AS ANSI_PADDING,
        SESSIONPROPERTY('ANSI_WARNINGS') AS ANSI_WARNINGS,
        SESSIONPROPERTY('ARITHABORT') AS ARITHABORT,
        SESSIONPROPERTY('CONCAT_NULL_YIELDS_NULL') AS CONCAT_NULL_YIELDS_NULL,
        SESSIONPROPERTY('QUOTED_IDENTIFIER') AS QUOTED_IDENTIFIER,
        SESSIONPROPERTY('NUMERIC_ROUNDABORT') AS NUMERIC_ROUNDABORT;
    ```
    
    Return values:
    
    * 1 = ON
    * 0 = OFF
    
    You can also check several settings using `sys.dm_exec_sessions`:
    
    ```sql
    SELECT
        quoted_identifier,
        arithabort,
        ansi_warnings,
        ansi_padding,
        ansi_nulls,
        concat_null_yields_null
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;
    ```
    
    `NUMERIC_ROUNDABORT` is not available in this DMV output. Use `SESSIONPROPERTY` to check it.
    
    ---
    
    ## 4. Deterministic and Nondeterministic Functions
    
    ### Deterministic
    
    A function is deterministic when it always returns the same result for the same input values.
    
    Examples:
    
    ```sql
    SELECT ABS(-100);
    SELECT UPPER('sandeep');
    ```
    
    ### Nondeterministic
    
    A function is nondeterministic when it can return different results for the same input values.
    
    Examples:
    
    ```sql
    SELECT GETDATE();
    SELECT NEWID();
    ```
    
    ### Why does determinism matter?
    
    SQL Server must guarantee consistent values for indexed computed columns and indexed views.
    
    Nondeterministic functions cannot be used in these indexed expressions.
    
    The same restrictions apply to user-defined functions.
    
    ### Checking function determinism
    
    ```sql
    SELECT OBJECTPROPERTY(
        OBJECT_ID('dbo.YourFunction'),
        'IsDeterministic'
    );
    ```
    
    Results:
    
    * 1 = Deterministic
    * 0 = Nondeterministic
    
    ---
    
    ## 5. Precision and Imprecision
    
    Determinism and precision are two different concepts.
    
    * Deterministic: Same inputs produce the same result.
    * Precise: The expression does not involve approximate numerical behaviour.
    
    Expressions involving `FLOAT` and `REAL` are considered imprecise.
    
    This is because their results may vary across different processor architectures or implementations.
    
    An imprecise computed value can be used as an index key when it is physically stored rather than recomputed.
    
    This is where `PERSISTED` becomes important.
    
    ---
    
    ## 6. Schema Binding
    
    Schema binding is required when creating indexed views.
    
    It protects the underlying table structure from incompatible schema changes.
    
    ### Example
    
    ```sql
    CREATE VIEW dbo.vw_Employee
    WITH SCHEMABINDING
    AS
    SELECT
        EmployeeID,
        Salary
    FROM dbo.Employee;
    ```
    
    Important points:
    
    * All referenced tables must use two-part names (`schema.object`).
    * Underlying tables or referenced columns cannot be changed incompatibly while the view is schema-bound.
    * The view must be dropped or altered before making incompatible schema changes.
    * If the underlying table has a different owner, the creator may need REFERENCES permission.
    
    ---
    
    # 7. Indexes on Computed Columns
    
    SQL Server allows indexes on computed columns when the requirements are satisfied:
    
    1. The expression must be deterministic.
    2. The expression must be precise, or the computed column must be persisted if imprecise.
    3. The resulting data type must be indexable.
    4. Required SET options must be correct.
    
    LOB data types such as `text`, `varchar(max)`, and `xml` cannot be used as index key data types.
    
    A qualifying computed column can be:
    
    * An index key.
    * An included column.
    * Part of a PRIMARY KEY or UNIQUE constraint, subject to the applicable requirements.
    
    ### Example 1: Deterministic computed column
    
    ```sql
    CREATE TABLE dbo.Employee
    (
        EmployeeID INT,
        Salary DECIMAL(10,2),
        Bonus AS (Salary * 0.10)
    );
    GO
    
    CREATE NONCLUSTERED INDEX IX_Employee_Bonus
    ON dbo.Employee(Bonus);
    GO
    ```
    
    The expression is deterministic because the same Salary value always produces the same Bonus.
    
    ### Example 2: Nondeterministic computed column
    
    ```sql
    CREATE TABLE dbo.t2
    (
        a INT,
        b DATETIME,
        c AS DATENAME(MM, b)
    );
    GO
    
    CREATE INDEX i2
    ON dbo.t2(c);
    GO
    ```
    
    This index creation fails because `DATENAME()` can return different month names depending on the language setting.
    
    ### Checking computed-column properties
    
    Check whether a column is computed:
    
    ```sql
    SELECT COLUMNPROPERTY(
        OBJECT_ID('dbo.t2'),
        'c',
        'IsComputed'
    );
    ```
    
    Check determinism:
    
    ```sql
    SELECT COLUMNPROPERTY(
        OBJECT_ID('dbo.t2'),
        'c',
        'IsDeterministic'
    );
    ```
    
    Check indexability:
    
    ```sql
    SELECT COLUMNPROPERTY(
        OBJECT_ID('dbo.t2'),
        'c',
        'IsIndexable'
    );
    ```
    
    Check precision:
    
    ```sql
    SELECT COLUMNPROPERTY(
        OBJECT_ID('dbo.t2'),
        'c',
        'IsPrecise'
    );
    ```
    
    Results generally return:
    
    * 1 = Yes
    * 0 = No
    
    `IsIndexable` is a useful quick check, but it does not explain why a column is not indexable.
    
    ---
    
    ## 8. Physical Implementation of Computed Columns
    
    When an index is created on a computed column, the computed value physically exists in the leaf level of that index.
    
    Example:
    
    ```sql
    CREATE TABLE dbo.Employee
    (
        EmployeeID INT,
        Salary INT,
        Bonus AS (Salary * 0.10)
    );
    GO
    
    CREATE NONCLUSTERED INDEX IX_Employee_Bonus
    ON dbo.Employee(Bonus);
    GO
    ```
    
    Conceptual NCI leaf structure:
    
    | Bonus (key) | Row locator |
    | ----------- | ----------- |
    | 5000        | EmployeeID  |
    | 6000        | EmployeeID  |
    | 7000        | EmployeeID  |
    
    The computed value is physically stored in the nonclustered index.
    
    When the underlying Salary column changes, SQL Server recalculates Bonus and maintains the affected index entry.
    
    ### Important distinction
    
    | Scenario                  | Base table | NCI leaf |
    | ------------------------- | ---------- | -------- |
    | Non-persisted, no index   | Not stored | No index |
    | Non-persisted, with index | Not stored | Stored   |
    | Persisted, no index       | Stored     | No index |
    | Persisted, with index     | Stored     | Stored   |
    
    Creating an index does not automatically make a computed column PERSISTED.
    
    ---
    
    ## 9. Persisted Computed Columns
    
    A computed column marked `PERSISTED` stores its computed value physically in the base table.
    
    Example:
    
    ```sql
    CREATE TABLE dbo.Employee
    (
        EmployeeID INT,
        Salary DECIMAL(10,2),
        Bonus AS (Salary * 0.10) PERSISTED
    );
    ```
    
    ### Why use PERSISTED?
    
    One important use case is computed expressions involving `FLOAT` and `REAL`.
    
    The book demonstrates this with the Northwind Order Details table.
    
    The Discount column is of type REAL.
    
    First, create the computed column:
    
    ```sql
    ALTER TABLE [Order Details]
    ADD Final AS
    (
        (Quantity * UnitPrice)
        - Discount * (Quantity * UnitPrice)
    );
    GO
    ```
    
    Attempt to create an index:
    
    ```sql
    CREATE INDEX OD_Final_Index
    ON [Order Details](Final);
    GO
    ```
    
    The operation fails because the computed column is imprecise and not persisted.
    
    ### Solution
    
    ```sql
    ALTER TABLE [Order Details]
    DROP COLUMN Final;
    GO
    
    ALTER TABLE [Order Details]
    ADD Final AS
    (
        (Quantity * UnitPrice)
        - Discount * (Quantity * UnitPrice)
    ) PERSISTED;
    GO
    
    CREATE INDEX OD_Final_Index
    ON [Order Details](Final);
    GO
    ```
    
    Now SQL Server can index the persisted imprecise computed column.
    
    ### Checking precision
    
    ```sql
    SELECT COLUMNPROPERTY(
        OBJECT_ID('dbo.Employee'),
        'Bonus',
        'IsPrecise'
    );
    ```
    
    The book also explains that computed columns used as partitioning columns must explicitly be marked PERSISTED, whether precise or imprecise.
    
    ---
    
    # 10. Indexed Views
    
    An indexed view is similar to a materialized view in other database systems.
    
    A normal view stores a SELECT definition.
    
    An indexed view physically stores the result data.
    
    One important use case is precomputing aggregate results from large tables.
    
    For example, calculating total sales per product from millions of sales records can be expensive.
    
    An indexed view can store the precomputed aggregate values.
    
    ### First index requirement
    
    The first index created on a view must be a UNIQUE CLUSTERED INDEX.
    
    Why?
    
    The clustered index leaf level contains the actual data rows.
    
    Therefore, creating a unique clustered index physically materializes the view's result data.
    
    ---
    
    ## 11. Additional Restrictions on Indexed Views
    
    The following are restricted in indexed view definitions according to the book:
    
    | Restricted element           |
    | ---------------------------- |
    | TOP                          |
    | LOB columns                  |
    | DISTINCT                     |
    | MIN                          |
    | MAX                          |
    | COUNT(*)                     |
    | COUNT(expression)            |
    | STDEV                        |
    | VARIANCE                     |
    | AVG                          |
    | SUM on a nullable expression |
    | Derived tables               |
    | ROWSET function              |
    | Another view                 |
    | UNION                        |
    | Subqueries                   |
    | OUTER JOINs                  |
    | Self-joins                   |
    | Full-text predicates         |
    | COMPUTE                      |
    | COMPUTE BY                   |
    | ORDER BY                     |
    
    ### GROUP BY requirements
    
    If the view contains GROUP BY:
    
    1. The SELECT list must include `COUNT_BIG(*)`.
    2. HAVING is not allowed.
    3. CUBE is not allowed.
    4. ROLLUP is not allowed.
    5. GROUP BY ALL is not allowed.
    6. All GROUP BY columns must appear in the SELECT list.
    
    ### Why COUNT_BIG(*)?
    
    `COUNT_BIG(*)` returns a BIGINT (8-byte integer).
    
    It is required for grouped indexed views.
    
    ### Calculating AVG
    
    Although AVG is restricted, an equivalent calculation can be performed using:
    
    ```sql
    SUM(Amount) / COUNT_BIG(*)
    ```
    
    ### Checking view indexability
    
    ```sql
    SELECT OBJECTPROPERTY(
        OBJECT_ID('dbo.vw_ProductSales'),
        'IsIndexable'
    );
    ```
    
    A result of 1 means the view meets the indexability requirements.
    
    ---
    
    # 12. Creating an Indexed View
    
    Example based on the AdventureWorks database:
    
    ```sql
    USE AdventureWorks2012;
    GO
    
    CREATE VIEW dbo.Vdiscount1
    WITH SCHEMABINDING
    AS
    SELECT
        SUM(UnitPrice * OrderQty) AS SumPrice,
        SUM(UnitPrice * OrderQty * (1.00 - UnitPriceDiscount))
            AS SumDiscountPrice,
        COUNT_BIG(*) AS Count,
        ProductID
    FROM Sales.SalesOrderDetail
    GROUP BY ProductID;
    GO
    ```
    
    At this stage, it is still a normal view.
    
    It does not yet have physically materialized result rows.
    
    ### Create the unique clustered index
    
    ```sql
    CREATE UNIQUE CLUSTERED INDEX VDiscount_Idx
    ON dbo.Vdiscount1(ProductID);
    GO
    ```
    
    Now the view is materialized.
    
    The clustered index leaf level contains the actual aggregated view data.
    
    ### Verify physical storage
    
    ```sql
    SELECT
        si.name AS IndexName,
        ps.used_page_count,
        ps.reserved_page_count,
        ps.row_count
    FROM sys.dm_db_partition_stats AS ps
    JOIN sys.indexes AS si
        ON ps.object_id = si.object_id
       AND ps.index_id = si.index_id
    WHERE ps.object_id = OBJECT_ID('dbo.Vdiscount1');
    ```
    
    The book's example shows:
    
    | Index        | Used pages | Reserved pages | Rows |
    | ------------ | ---------: | -------------: | ---: |
    | VDiscountIdx |          4 |              4 |  266 |
    
    This demonstrates that the view's result data is physically stored.
    
    ### Indexed view maintenance
    
    SQL Server automatically maintains the indexed view when underlying data changes.
    
    For example:
    
    * INSERT operations can add or update aggregated rows.
    * UPDATE operations can change existing aggregated values.
    * DELETE operations can reduce or remove aggregated rows.
    
    Unlike a temporary table, the indexed view automatically reflects changes to the underlying tables.
    
    **Important:** This automatic maintenance introduces additional write overhead.
    
    After creating the unique clustered index, you can create additional nonclustered indexes on the view.
    
    ### Checking whether a view is indexed
    
    ```sql
    SELECT OBJECTPROPERTY(
        OBJECT_ID('dbo.Vdiscount1'),
        'IsIndexed'
    );
    ```
    
    A result of 1 indicates that the view is indexed.
    
    ---
    
    # 13. Using Indexed Views
    
    The Query Optimizer can sometimes use an indexed view even when the query does not explicitly reference it.
    
    Example:
    
    ```sql
    SELECT
        ProductID,
        SUM(UnitPrice * OrderQty) AS TotalSales
    FROM Sales.SalesOrderDetail
    GROUP BY ProductID;
    ```
    
    If an indexed view already contains the required aggregated data, the optimizer can evaluate whether using that view is cheaper than accessing the underlying table.
    
    The base table might not need to be accessed.
    
    ### Does SQL Server always use an indexed view?
    
    No.
    
    The Query Optimizer chooses an execution plan based on cost.
    
    Even when a query explicitly references the view, SQL Server might access the underlying tables instead.
    
    ### NOEXPAND hint
    
    You can use `NOEXPAND` to prevent expansion of a referenced indexed view.
    
    ```sql
    SELECT *
    FROM dbo.Vdiscount1 WITH (NOEXPAND);
    ```
    
    Use hints only after comparing execution plans and measuring performance.
    
    ---
    
    # 14. Important DBA Takeaways
    
    | Concept                  | Key takeaway                                    |
    | ------------------------ | ----------------------------------------------- |
    | Computed column          | Derives values from other columns               |
    | PERSISTED                | Stores computed values in the base table        |
    | Index on computed column | Stores computed values in the index             |
    | Deterministic            | Same inputs produce the same result             |
    | Nondeterministic         | Same inputs can produce different results       |
    | Precise                  | Does not have approximate numerical behaviour   |
    | Schema binding           | Protects underlying schema dependencies         |
    | Indexed view             | Physically stores view results                  |
    | Unique clustered index   | Materializes indexed view data                  |
    | COUNT_BIG(*)             | Required for GROUP BY indexed views             |
    | NOEXPAND                 | Prevents expansion of a referenced indexed view |
    
    ## 15. Practical DBA Considerations
    
    Before creating these indexes, evaluate:
    
    * Determinism.
    * Precision.
    * Data type eligibility.
    * Required SET options.
    * Schema-binding requirements.
    * Storage overhead.
    * Additional write-maintenance overhead.
    * Whether the optimizer actually uses the index.
    
    The goal is not simply to create more indexes. It is to improve query performance without introducing unnecessary storage and write costs.

