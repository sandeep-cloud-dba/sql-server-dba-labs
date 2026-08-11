# Notes for Grant_Fritcheysql
    select * from sys.sql_modules -- check the code of SP
    #Hash is created for a SQL Plan and stored in plan cache, 
    #Optimizer uses the hash to determine if the exists in plan cache and if it is valid.
    #A plan is no0longer valid after making changes to query (even a simple space)
    #Plan evaluation is a heuristic process.

 
# Cardinality Estimation (CE)
	Definition
	Cardinality Estimation (CE) is SQL Server's process of estimating how many rows each operator in an execution plan will process.
	The optimizer uses these estimates to choose the lowest-cost execution plan.
	
# Why is CE important?
	Almost every optimizer decision depends on Cardinality Estimation:
	Seek vs Scan
	Nested Loops vs Hash Match vs Merge Join
	Memory Grant
	Parallelism
	Sort operations
	Spool usage
	Wrong estimates → Wrong execution plan → Poor performance

# SQL Server 2014 Cardinality Estimator
	SQL Server 2014 introduced a new Cardinality Estimator (CE).
	Previous CE remained unchanged since SQL Server 7.0.
	Same query can produce different execution plans because of different row estimation logic.
    
    Plan Age=Estimated CPU cost for compiling the plan * numbr of time it has been used
    Plan age = 10 * 5 =  50 

# The importance of statistics.
	Definition
	
	Statistics are metadata (data about data) describing data distribution.
	
	SQL Server uses statistics to estimate:
	
	Number of rows
	Selectivity
	Data distribution
	Cardinality
	
	Statistics are the primary input for Cardinality Estimation.

    1. Execution plan is heavily dependent on the Statistics
    2. Every time the query is executed it does not read the data from the table to create execution plan, instead it uses the statistics that represent the entire data collection
    3. The estimated cost of an execution plan depends largely on its cardinality estimations, in other words, its knowledge of how many rows are in a table, and its estimations 
	   of how many of those rows satisfy the various search and join conditions, and so on.
	4. Exists only for the leading (left-most) column

# When SQL Server Creates Statistics
	1. Index Statistics (Automatic)
		Whenever an index is created:
			SQL Server automatically creates an associated Statistics object.
			Exists as long as the index exists.
			
	2. Index Rebuild
		Index Rebuild recreates the index.
		Therefore:
			Statistics are automatically updated.
			Uses FULLSCAN.
		Therefore updating index statistics immediately after an Index Rebuild is usually unnecessary.
		Only auto-created column statistics may still require updating.

	3. Auto Create Statistics
		If AUTO_CREATE_STATISTICS is enabled (default):
		SQL Server automatically creates single-column statistics when
			column is used in WHERE clause
			column is used in JOIN
			column is NOT already the leading column of an existing index.

	4. Manual Statistics
		Can be created using
			CREATE STATISTICS
		Supports
			Single-column
			Multi-column statistics
	
		SQL Server automatically updates statistics if Auto Update Statistics is enabled and 500 + 20% (of total) modified rows
	
		Modern SQL Server
			Starting with SQL Server 2016 (or SQL Server 2014 SP1 with Trace Flag 2371, later enabled by default), the threshold becomes dynamic for large tables. 
			Large tables no longer wait for a full 20% of rows to change before statistics are updated.
	
	Interview answer: Mention that SQL Server automatically updates statistics, but large tables use a dynamic threshold in modern versions.

	This is the single most important takeaway from the chapter.
			Statistics
		        ↓
		Cardinality Estimation
		        ↓
		Estimated Rows
		        ↓
		Execution Plan
		        ↓
		Performance

		Statistics don't improve query performance directly; they improve the optimizer's row estimates, which leads to better execution plans.


# Ascending Key Problem ⭐
	Occurs when the leading index column continuously increases.
	Examples
		Identity
		Date
		DateTime
	Example
		OrderDate
	
	Statistics updated Sunday.
	New rows inserted Monday–Saturday.
	Histogram doesn't know about these new values.
	Result
	Estimated Rows
		1
	Actual Rows
		5000

	Large estimation errors.
	Very common in OLTP systems.

	Why Ascending Key Causes Problems
	Histogram contains only existing values.
	New values beyond histogram range are unknown.
	Optimizer underestimates row count.
		Leads to
			Wrong Join
			Wrong Memory Grant
			Wrong Parallelism
			TempDB Spill


# Manually Clearing Plan cache
    ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE --remove all plans for single database

# Criteria for Plan Reuse
    1. SQL text → must be exactly identical (even spaces matter).
    2. SET options → session settings (ANSI_NULLS, QUOTED_IDENTIFIER, etc.) must match.
    3. Database ID → identical queries in different databases create different plans.
    4. dbo.Table vs Table may lead to different plans.

# Avoid Cache Churn
    1. Ad-hoc queries with literal values  - SQL will complete the full optimization process and compile a new plan each time
    2. To avoid it better use Sprocs or parameterized queries
    3. Another way to optimize it use a server setting called "Optimize For Ad Hoc Workloads"
	4. sp_executesql, use this to avoid the cache churn

# Actions trigger recompile
    • changing the structure of a table, view or function referenced by the query
    • changing, or dropping, an index used by the query
    • updating the statistics used by the query
    • calling the function sp_recompile
    • mixing DDL and DML within a single batch
    • changing certain SET options within the T-SQL of the batch
    • changes to cursor options within the query
    • deferred compiles
    • changes to a remote rowset if you're using a function like OPENQUERY.

# Execution plan formats
    1. XML
    2. text
    3. graphical
    # XML Plan
    SET SHOWPLAN_XML ON – generates the estimated plan (i.e. the query is not executed).
    SET STATISTICS_XML ON – generates the actual execution plan (i.e. with runtime information).

# Estimated and Actual execution plan
    1. there is only one execution plan (both will essentially same)
    2. Actual Execution  Plan-  will have the run time values
    3. Estimated  -  does not but the plan will mostly be same 

# Getting Started with Reading Plans
    1. Two Types of operator (physical and Logical)
    2. Inner/LeftlRight etc Join  -  Logical
    3. Nested Loop / Hash Match etc  -  Physical

# Blocking Operators
    Sort, hash Match, Adaptive Join -  require variable amount of memory to execute
    Query with one of these operators may have to wait for available memory prior to execution, possibly adversly affecting the performance

# Reading Plan
    > Mostly the plans are read from right to left and top to bottom (in the way data flows)
    > But it is equally valid to read from left to right   (in the way operators are called)  
    > Like top operator and clustered index scan (where it is returning only the top values)

# Estimated VS actual number of rows 
    > all costs in plan are based on cardinality estimation (therefore these costs are only as accurate as the optimizer's cardinality estimation)


# Are Scan bad
    1. If we need all or most rows from a table, a scan is often the most efficient operation and is not considered bad.
    2. If SQL Server scans a very large number of rows to return only a few rows, it can become inefficient because of 
	   unnecessary IO and logical reads. This may happen due to:
        > missing or poor indexes
        > stale statistics
        > non-SARGable queries (functions or expressions on indexed columns)
        > poor query design
        > cardinality estimation
    3. Sometimes SQL Server may still choose a scan even when indexes and statistics are good. In such cases, we should investigate:
        > estimated vs actual rows
        > query predicates
        > parameter sniffing
        > optimizer cost decisions
        > whether returning many rows actually makes a scan cheaper than a seek
    4. One Important Point
       A Seek is not always faster than scan
       If A query returns a large percentage of rows, SQL may intentinally choose a scan because
       > many seeks + lookup cost more
       > sequential reads are efficient

# INDEX SEEK (CLUSTERED)
    1. In a seek operation, SQL Server directly navigates to the page(s) containing the required rows or to the start/end of a range, instead of scanning the entire index/table.
    2. Just like scans, seeks are not always good or bad. Seeks are usually efficient for retrieving a small number of rows from a large table.
    3. A seek can become inefficient if the optimizer underestimates the number of rows due to inaccurate statistics. This can lead to excessive key lookups or repeated reads.
    4. A seek occurs when:
       > an index exists on the predicate column and the index covers the query
         OR
       > an index exists on the predicate column, does not fully cover the query, but the predicate is highly selective and returns only a small number of rows.
    5. If the index does not cover the query:
        SQL Server may perform:
        > Index Seek + Key Lookup
        > Index Seek + RID Lookup

# INDEX SEEK (NON-CLUSTERED)
    1. This works same as the clustered index seek only difference is we see predicate and seek predicate in properties (hover over the operator)
    2. NCI contain the index key + clustered index key + include columns (any columns that are included through include)

# KEY LOOKUPS
    1. When the nonclustered index does not contain all the columns required by the query, SQL Server performs a Key Lookup to the clustered index to retrieve the missing columns.
    2. A Key Lookup happens after an Index Seek (or sometimes Index Scan) on the nonclustered index.
    3. A Key Lookup can be avoided by creating a covering index using:
       > additional key columns
       > INCLUDE columns
    4. However, it is not a good idea to create covering indexes for every query because too many indexes:
       > increase storage
       > slow down INSERT/UPDATE/DELETE operations
       > increase maintenance overhead
    5. A Key Lookup is usually acceptable for a small number of rows, but it becomes expensive when executed many times.

# Table Scan
    1. Table Scans occur only against the Heap tables
    2. Table Scan can occur due to the absence of a useful nonclustered index.
    3. If a query requests all or most of the rows, SQL Server may choose a Table Scan because scanning can be cheaper than performing many index lookups.
    4. Even if a selective index exists, SQL Server may still choose a Table Scan when the table is very small.

# RID Lookup
    1. RID Lookup is similar to Key Lookup. (RID Lookup → happens on a heap (table without a clustered index).)
    2. The nonclustered index does not contain all the columns required by the query, so SQL Server performs a RID Lookup to fetch the missing columns from the heap.
    3. The nonclustered index stores a special value called the RID (Row Identifier). (The RID points directly to the location of the row in the heap.)
    4. The results from the Index Seek and RID Lookup are combined using a Nested Loops operator.
    5. Bmk1000 = internal bookmark/RID value

# Joining Data - The optimizer might choose from one of the below physical operator to perform join
   
       Nested Loop
       Hash Match
       Merge Join
       Adaptive Join
   
   
# Nested loop Join

    1.takes data from outer input and process against the inner input for each row. if the outer input returns 290 rows, 
	  the inner input will be executed 290 times once for each row from outer input, each execution of inner side performs 
	  the efficient seek using the value pushed form the outer input.
    
	2. Nested loop is generally efficient when
           Outer Input is small
           Inner Input is indexed
           Matching rows can be found quickly using seeks
       
    4.A large Estimated vs Actual Rows difference doesn't automatically mean bad performance, but it is a strong clue 
	  that the optimizer may have chosen a suboptimal plan. This Could be because of
    
            Stale or missing Statistics on predicate 
            Volume or distribution of data has been changed significantly since the last stats, on the column
            distribution in column may be non uniform
            parameter sniffing may have occurred
       
    6. Nested loop properties - Outer References shows the values being pushed from the outer input to the inner input.
           Estimated vs Actual Rows
           Check for large discrepancies.  
        Possible causes:
	           Missing statistics
	           Stale statistics
	           Skewed data distribution
	           Non-SARGable predicates
	           Parameter sniffing
	           Plan reuse issues

# Rebind and Rewinds
    Rebind = New Value = Re-execute
    Rewind = Same Value = Reuse Cached Result
    Only meaningful when inner operator can save results
    (Spool, Sort, TVF, Remote Query)

Clustered Index Seek / Index Seek normally show 0 Rebinds and 0 Rewinds.
    <img width="766" height="533" alt="image" src="https://github.com/user-attachments/assets/803d71a5-f48c-4a28-ab3a-a2bedc027bb8" />
    <img width="688" height="797" alt="image" src="https://github.com/user-attachments/assets/ce2f5087-eef9-49b9-9f48-ab45dd4316d7" />
    <img width="484" height="675" alt="image" src="https://github.com/user-attachments/assets/1e22e08b-a72f-4437-ab24-c37d8d28622d" />
    <img width="439" height="433" alt="image" src="https://github.com/user-attachments/assets/68fc9934-c3e7-48b3-b3f3-42187d7ca025" />
    <img width="495" height="435" alt="image" src="https://github.com/user-attachments/assets/ae55986e-421f-410b-ae54-eb36e705a6d0" />
    <img width="364" height="389" alt="image" src="https://github.com/user-attachments/assets/fd6608cb-f6fa-4ae6-a71e-38c4538c8c76" />



# Opereator
    Below Operator Can save results from the previous execution (in this case only rebinds and rewinds are relevant)
    Index Spool
    Remote Query
    Row Count Spool
    Sort
    Table Spool
    Table Valued Function
    
# HASH MATCH (JOIN) -  In this operator
    
	Top Input -> Build (suppose return 290 rows)
    Bottom Input -> probe (Suppose rerun 19614 rows)
    Suppose SQL choose to perform the nested loop then 290 searches in 19614 rows would be expensive. Instead SQL will choose 
	HASH MATCH (Build the hash table form smaller input and search it against the bigger input)
    Build - > SQL will create the hash table in memory with smaller input (in this case with 290 rows) and put them in bucket
    Probe -> SQL will reads table (with 19614 rows) one row at a time, it computes the hash value of joined column and compares, then returns the rows
    
	Why Use Hash Match?
		Case 1 -> Large table and Large table
		Case 2 -> small table and Large Table 
		Case 3 -> No Useful Indexes

	Why Is Hash Match Called Blocking?
		Before producing the result (Hash match) must first build the hash table, So it must consume ALL build rows 

	Biggest Performance Problem
	    Hash Match needs memory.
	    Suppose optimizer estimates: Build Input = 1,000 rows, but reality is: Build Input = 1,000,000 rows. Hash table no longer fits in memory.
	    SQL Server spills to TempDB. This becomes: Memory -> Disk Very Expensive

	When Hash Match May Indicate a Problem
	    Missing Index
	    Non-SARGable Query (WHERE YEAR(OrderDate)=2025)
	    Implicit Conversion (WHERE IntColumn = '100')
		
	 Notes
	    Hash Match Join
	    Uses two inputs:
	        Build Input (top)
	        Probe Input (bottom)
	    SQL Server:
	        Builds hash table from smaller input
	        Probes larger input for matches
	    Best for:
	        Large unsorted datasets
	        Missing indexes
	        Large joins
	    Blocking operator: Must complete build phase first
	    Main risk: Memory spill to TempDB

	When you see a Hash Match in an execution plan, ask yourself:
	    Which input is Build?
	    Which input is Probe?
	    Why wasn't Nested Loops chosen?
	    Why wasn't Merge Join chosen?
	    Did the Hash Match spill to TempDB?

# MERGE JOIN

    1. Requires both the inputs to be ordered on JOIN column
    2. It takes two ordered inputs and merges them together by matching join column values.
    3. If one or both inputs are not ordered, SQL Server may add a Sort operator.
    4. Large Sort operators can be expensive. If you frequently see: Sort -> Merge Join, then check whether an index could provide the required ordering and eliminate the Sort.
    5. Merge Join can perform:
        One-to-One
        One-to-Many
        Many-to-Many -  When Duplicate exist on both the input (SQL Server must remember duplicate rows and may use a worktable in TempDB.) This is where Merge Join becomes more expensive.
The Most Important Property
    
    When you see Merge Join, check: Many To Many = False
    Many To Many = True (Investigate Duplicates exist on both sides. May require worktables and rewinds.)

When is Merge Join Usually Chosen?

    Case 1: When the inputs are already sorted
    Case 2: Large DataSets
    Case 3: Sorted indexes exist on join columns

# Sorting and Aggregating Data.
    Sort
    ----
    - Blocking operator.
    - Needs all rows before returning results.
    - Avoided if index already provides required order.
    
    Top N Sort
    ----------
    - Used with TOP + ORDER BY.
    - Returns only requested rows.
    
    Distinct Sort
    -------------
    - Sorts rows and removes duplicates.
    - Duplicates become adjacent after sorting.
    
    Sort Warning
    ------------
    - Usually indicates TempDB spill.
    - Caused by insufficient memory grant.
    - Often due to poor cardinality estimates.
    - SQL calculates memory grant based on Estimated Row and Estimated Row Size 
    - For Exampple Estimated Rows = 10,000, Memory allocated for 10,000 rows, Actual Rows = 75,000 (Memory becomes insufficient), sort -> tempdb spill
    
    Troubleshooting:
    Scan -> Compute Scalar -> Filter -> Sort
    
    Find first operator where
    Estimated Rows ≠ Actual Rows.

    Stream Aggregate 
        Requires ordered input.
        Can use:
        - Ordered Index Scan
        - Ordered Clustered Scan
        - Sort + Stream Aggregate
        
        Processes rows as they arrive.
        
        Usually memory efficient.

    Hash Aggregate
        Does not require ordered input.

        Builds a hash table in memory.
        
        Stores:
        - Grouping key
        - Aggregate calculations
        
        Used when sorting would be more expensive.
        
        Can spill to TempDB if memory grant is insufficient.

       NOTE: Creating an index on the GROUP BY column may allow SQL Server to use a Stream Aggregate instead of a Hash Aggregate.

        **Ordered Input
          ↓
    Stream Aggregate
    
    Unordered Input
          ↓
    Hash Aggregate
          OR
    Sort + Stream Aggregate
    
    Unordered Input
      ↓
    Optimizer evaluates
    
    Option A:
    Sort + Stream Aggregate
    
    Option B:
    Hash Aggregate
    
    Chooses cheaper option**

# Table Spool
    A Table Spool is a temporary work table that SQL Server creates in tempdb to store intermediate results for reuse.
    "SQL Server doesn't want to repeatedly execute an expensive operation, so it stores the result and reuses it."
    Example:
    Nested Loops
        |
    Table Spool
        |
    Index Seek
    
    Instead of repeatedly performing the Index Seek, SQL Server stores the result in a spool and reuses it.
    
    Why SQL Server Uses It
    Avoid repeated scans
    Avoid repeated seeks
    Support Nested Loop joins
    Support recursive queries
    Improve performance when data is reused
  
    DBA Perspective
    When you see a Table Spool:
    1. Why is SQL Server caching rows?
    2. Is it compensating for a missing index?
    3. Is tempdb being heavily used?
    4. Can query rewriting eliminate the spool?
        
            Rebind:
              Populate spool.
            
            Rewind:
              Reuse rows from spool.
        
              Plan:
        
                Hash Aggregate
                      ↓
                Table Spool
                      ↓
                Nested Loops
                
                SalesPerson rows:
                
                1
                1
                1
                2
                3
                4
                4
                5
                6
                6
                7
                8
                9
                10
                First Execution
                Rebind = 1
                
                SQL Server:
                
                Scan SalesOrderHeader
                Hash Aggregate
                Create Territory Totals
                Store in Worktable
                
                Result:
                
                TerritoryID | TotalTax
                ----------------------
                1
                2
                3
                ...
                10
                
                stored once.
                
                Remaining Executions
                Rewind = 13
                
                SQL Server:
                
                Reuse worktable
                
                No new scan.
                No new aggregate

				What is a Table Spool?
				Table Spool stores intermediate rows in a worktable (tempdb) so SQL Server can reuse them later instead of re-executing expensive operations.
				Always check these 3 properties
				Property			Why check?
				NodeID				Identifies the spool that created the worktable.
				PrimaryNodeID		Tells whether another spool is reusing that worktable.
				Logical Operation	Identifies whether it is Lazy Spool or Eager Spool.

# Index Spool
    An Index Spool is similar to Table Spool, but SQL Server creates a temporary indexed structure in tempdb.
    
    Why SQL Server Uses It
        Suppose SQL Server repeatedly searches rows using a particular key.
        Instead of scanning repeatedly:
        Create temporary index
               ↓
        Perform fast lookups

    DBA Interpretation
        When you see Index Spool:
        Often SQL Server is saying:
        "I wish I had a proper permanent index."

    Frequent Index Spools often indicate:
        Missing indexes
        Poor indexing strategy
        Suboptimal query design

            Rebind:
              Populate spool for new key.
            
            Rewind:
              Reuse previously cached value(s)
              through indexed lookup.
        
                  Plan:
        
                Index Seek
                     ↓
                Stream Aggregate
                     ↓
                Index Spool
                     ↓
                Nested Loops
                
                SalesPerson rows:
                
                1
                1
                1
                2
                3
                4
                4
                5
                6
                6
                7
                8
                9
                10
                
                Distinct Territories:
                
                1,2,3,4,5,6,7,8,9,10
                
                Total:
                
                10 distinct values
                TerritoryID = 1
                Rebind
                
                Execute:
                
                Index Seek
                Stream Aggregate
                Store result in Index Spool
                TerritoryID = 1 again
                Rewind
                
                Reuse cached result.
                
                No seek.
                
                No aggregate.
                
                TerritoryID = 2
                Rebind
                
                New value.
                
                Need new seek.
                
                Need new aggregate.
                
                Store result.
                
                Final counts:
                
                10 distinct TerritoryIDs
                
                Therefore:
                
                10 Rebinds
                
                and
                
                14 total rows
                -10 distinct rows
                ----------------
                4 Rewinds

# Execution Plans for Data Modifications







# Things to Remember
    1. Query Hash -  hash value of query, which is stored with the plan and used by optimizer to reuse the plan
    2. for plan to be reused SET options and Database_ID should be same
    3. QueryPlanHash -  Hash value of the query plan
    4. Rebinds and Rewinds (Estimated and Actual) - are only imp when dealing with the Nested loops
    5. When the query has no WHERE clause, SQL Server must perform a scan. The optimizer chooses the nonclustered index(if there) because it is smaller than the clustered index and still contains the required columns (Clustered key is included in NCI), resulting in lower IO and better performance.
    6. Once you approach:     5%-20% of a table, SQL Server often starts preferring scans over seeks + lookups.
 
# Things to do for practice
    1. Go to the properties of each operator and check it's value
    2. how check operator's are using which stats
    3. before digging deeper always first compare estimated vs actual row counts and make sure they are not too off
    4. if there is huge difference between actual vs estimated then there may be stats are not correct and need to fix the cardinality
    5. fat line start and thin on left suggest filtering happening later (it is good if filtering happen at start) and thin at start and fat later means data is multiplying
    6. check for high cost scan that retrive limited dataset or or seeks that retrive extremly large datasets.
    7. if you want plan to be reused, parametrized the query

# Useful Tools and Techniques when Reading Plans
    1. use SET STATISTICS IO ON; and SET STATISTICS TIME ON;
    2. Query Store
    3. Extended Events
    4. Profiler

# What to Look For in an Execution Plan
    1. First Operator (SELECT/UPDATE/etc.) -  (contains: compile time, compile CPU, memory usage, optimization level, parameter sniffing info, SET options, QueryHash, QueryPlanHash)
    2. Important SELECT Operator Properties
         3. Cached Plan Size -> Memory consumed in plan cache -> Large plans can pressure cache memory.
         4. CardinalityEstimationModelVersion
         5. CompileCPU / CompileTime / CompileMemory -> High compile time may indicate: -> overly complex queries -> excessive joins
    4. Warnings ⚠️ Yellow/red exclamation marks  - (Possible issues: memory spills, tempdb spills, implicit conversions, excessive memory grants)
    5. Estimated vs Actual Rows CRITICAL. - Execution plan costs are based on estimates. If estimates are wrong: optimizer chooses bad plans, wrong joins, bad            memory grants, spills, slow queries
    6. Operator Cost - (Good for: comparing operators INSIDE SAME PLAN,  Bad for: comparing between plans, Why? Costs are mathematical estimates, not real                execution time.)
    7. Missing Index Suggestions - (Treat as hints, NOT commands.)
    8. Data Flow Thickness (Pipes) - (Thicker arrows = more rows. Watch for: fat pipes suddenly becoming thin → filtering happening too late, thin pipes becoming         huge → row multiplication problem)
    9. Extra Operators - If you see an operator you don't understand:
    10. Scans vs Seeks  - (Seek Efficient when: retrieving small data sets Bad when: retrieving huge data sets repeatedly) & (Scan Efficient when: reading large           portions of table Bad when: returning very few rows)
    11. If there is any expensive operator first check "WHY IT IS THERE once clarified check is it really necessary"
	12. If you see table spool, Check NodeID and PrimaryNodeID, suppose if the NodeID is 21 and PrimaryNodeID is 7 that means Node 21 is not newly created, it has been reused from 7
	13. Easy rule to remember
		Estimate accuracy: Estimated Rows for All Executions ↔ Actual Rows for All Executions
		Reading efficiency: Actual Rows Read ↔ Actual Rows for All Executions
		Now imagine:
			Actual Number of Rows Read = 10,000
			Actual Number of Rows for All execution = 10
		That means SQL has to read 10000 rows to return 10 rows (🚩That should make you investigate things like a residual Predicate, whether the predicate is SARGable,
		SQL Server had to read 10,000 rows to produce only 10 rows.
		and whether the index keys are appropriate.)
	14. Whenever you see TOP, immediately look for:
			Estimated Number of Rows Without Row Goal
			That property tells you:
			"How many rows would SQL Server expect if TOP wasn't influencing this operator?"
	15. Every Operator  -  Check if it is a blocking operator or the streaming operator
	16. When you see a Hash Match in an execution plan, ask yourself:
	    Which input is Build?
	    Which input is Probe?
	    Why wasn't Nested Loops chosen?
	    Why wasn't Merge Join chosen?
	    Did the Hash Match spill to TempDB?
	


  
  
  # Question to be asked when evaluating the execution Plan
    1. Why Stream / Hash Aggregate, Scan Seek etc
    2. Is Input already Ordered
    3. Could an Index eliminate the Hash Aggregate or Hash Match
    4. Is the predicate selective enough?
    5. Does the index cover the query?
    6. Would seeks require many lookups?
    7. Is the query returning a large percentage of the table?
    8. Is a later operator (Sort, Window Function, Aggregate) dominating the cost anyway?
    9. why clustered index scan on table
		> How many rows exist?
		> How many rows are returned?

# Pro Way to Analyze UPDATE Plans
	Q.1: How did SQL Server find the rows? (Clustered Index Scan or Index Seek)
	Q.2: Which column caused this operator? (look at the predicate)
	Q.3: Why Scan? ( and not seek)
	Q.4: Is SQL reading too much?




