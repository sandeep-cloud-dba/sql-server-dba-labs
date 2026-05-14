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






  
