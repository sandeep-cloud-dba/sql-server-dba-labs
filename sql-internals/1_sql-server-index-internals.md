
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
