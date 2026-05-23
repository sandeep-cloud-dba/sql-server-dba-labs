# Notes for Grant_Fritcheysql
select * from sys.sql_modules -- check the code of SP

#Hash is created for a SQL Plan and stored in plan cache, 
#Optimizer uses the hash to determine if the exists in plan cache and if it is valid.
#A plan is no0longer valid after making changes to query (even a simple space)
#Plan evaluation is a heuristic process.

# The importance of statistics
1. Execution plan is hevaily dependent on the Statistics
2. Eevery time the query is executed it does not read the data from the table to create execution plan, instead it uses the statistics that represent the entire data collection
3. The estimated cost of an execution plan depends largely on its cardinality estimations, in other words, its knowledge of how many rows are in a table, and its estimations of how many of those rows satisfy the various search and join conditions, and so on.

# New cardinality estimator in SQL Server 2014
1. CardinalityEstimationModelVersion, is this is 70 or less then it is old cardinality and if it is more than 70 then it is an new.

Plan Age=Estimated CPU cost for compiling the plan * numbr of time it has been used
Plan age = 10 * 5 =  50


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
  > Mostly the plans are read from righ to left and top to bottom (in the way data flows)
  > But it is equally valid to read from left to right   (in the way operators are called)  
  > Like top operator and clustered index scan (where it is returning only the top values)

# Estimated VS actual number of rows 
 > all costs in plan are based on cardinality estimation (therefore these costs are only as accurate as the optimizers cardinality estimation)
>
> 





# Things to Remember
  1. Query Hash -  hash value of query, which is stored with the plan and used by optimizer to reuse the plan
  2. for plan to be reused SET options and Database_ID should be same
  3. QueryPlanHash -  Hash value of the query plan




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
  5. Estimated vs Actual Rows CRITICAL. - Execution plan costs are based on estimates. If estimates are wrong: optimizer chooses bad plans, wrong joins, bad memory grants, spills, slow queries
  6. Operator Cost - (Good for: comparing operators INSIDE SAME PLAN,  Bad for: comparing between plans, Why? Costs are mathematical estimates, not real execution time.)
  7. Missing Index Suggestions - (Treat as hints, NOT commands.)
  8. Data Flow Thickness (Pipes) - (Thicker arrows = more rows. Watch for: fat pipes suddenly becoming thin → filtering happening too late, thin pipes becoming huge → row multiplication problem)
  9. Extra Operators - If you see an operator you don't understand:
  10. Scans vs Seeks  - (Seek Efficient when: retrieving small data sets Bad when: retrieving huge data sets repeatedly) & (Scan Efficient when: reading large portions of table Bad when: returning very few rows)
  
  
  








