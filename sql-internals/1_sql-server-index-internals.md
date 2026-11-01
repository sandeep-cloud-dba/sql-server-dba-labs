
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
