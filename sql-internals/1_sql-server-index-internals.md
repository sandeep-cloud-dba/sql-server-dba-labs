
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

### Constraints and Indexes
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
  
  10. Uniqueness provides useful cardinality information to
      the optimizer because a unique predicate can return
      at most one row.
