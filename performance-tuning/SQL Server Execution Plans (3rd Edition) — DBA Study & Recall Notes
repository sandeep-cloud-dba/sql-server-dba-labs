# SQL Server Execution Plans (3rd Edition) — DBA Study & Recall Notes

Based on the book by Grant Fritchey.
Purpose of these notes:

* Rapid recall during real-world tuning
* Interview + troubleshooting preparation
* Operator behavior understanding
* Practical implementation mindset

---

# Golden Rules Before Reading Any Plan

## The 80/20 Execution Plan Checklist

Always check these first:

1. Estimated Rows vs Actual Rows
2. Index Seek vs Scan
3. Key Lookup / RID Lookup
4. Warnings (spill, implicit conversion, missing stats)
5. Sort / Hash Match cost
6. Parallelism operators
7. Memory Grant
8. Predicate vs Residual Predicate
9. Expensive operators are NOT always the problem
10. Read plans RIGHT → LEFT and TOP → BOTTOM

---

# Universal Tuning Workflow

## Step-by-Step

1. Identify expensive query
2. Capture actual execution plan
3. Compare estimated vs actual rows
4. Find largest data movement
5. Check scans and lookups
6. Verify indexes
7. Check SARGability
8. Check join types
9. Check memory grant/spills
10. Re-test after every change

---

# Chapter 1 — Introducing Execution Plans

## Core Concepts

Execution Plan = SQL Server's strategy to execute a query.

Optimizer decides:

* Join order
* Access methods
* Join types
* Parallelism
* Memory grants
* Operator selection

Compilation Phases:

1. Parsing
2. Binding (Algebrizer)
3. Optimization
4. Execution

## Important Concepts

### Plan Cache

Stores reusable plans.

Benefits:

* Saves CPU
* Faster compilation

Problems:

* Parameter sniffing
* Bad plan reuse
* Cache bloat

### Estimated vs Actual Plan

Estimated:

* No execution
* Uses statistics estimates

Actual:

* Query executed
* Includes runtime metrics
* Preferred for tuning

## Real DBA Recall

If estimates are wrong → optimizer decisions become wrong.

Bad estimates cause:

* Wrong joins
* Spills
* Excessive memory
* Parallelism issues
* Scans

## Tuning Techniques

### Technique 1 — Compare Estimated vs Actual Rows

Rule:

* Big mismatch = statistics/cardinality issue.

### Technique 2 — Watch Plan Reuse

Look for:

* Parameter sniffing
* Different runtime values
* Inconsistent performance

## Practical Task

1. Run same query with different parameters.
2. Compare plans.
3. Observe reused plan behavior.
4. Clear plan cache in test environment.
5. Re-run query.

## Knowledge Test

1. Why does SQL Server cache plans?
2. Difference between estimated and actual plans?
3. Why are statistics critical?
4. What causes recompilation?
5. Why can plan reuse become dangerous?

---

# Chapter 2 — Understanding Graphical Execution Plans

## Reading Direction

Read:
RIGHT → LEFT
TOP → BOTTOM

Data flows right to left.

## Cost Percentages

DO NOT blindly trust operator cost %.

Reason:

* Cost is optimizer estimate
* Not actual runtime

## Operator Categories

### Access Operators

* Index Seek
* Index Scan
* Table Scan
* Key Lookup

### Join Operators

* Nested Loop
* Merge Join
* Hash Match

### Aggregation Operators

* Stream Aggregate
* Hash Aggregate

### Data Movement

* Sort
* Spool
* Parallelism

## Critical Properties

Always inspect:

* Actual Rows
* Estimated Rows
* Actual Executions
* Predicate
* Output List
* Warnings
* Ordered = True/False
* Parallel = True/False

## Tuning Techniques

### Technique 1 — Hover Every Expensive Operator

Especially:

* Sort
* Hash Match
* Lookup
* Parallelism

### Technique 2 — Find Residual Predicate

Residual predicate means:
SQL Server had to filter AFTER reading rows.

Usually indicates:

* Poor index design
* Non-SARGable predicate

## Practical Task

1. Capture actual plan.
2. Identify all scans.
3. Check predicates.
4. Determine why seek wasn't chosen.

## Knowledge Test

1. Why are operator percentages misleading?
2. Difference between seek predicate and residual predicate?
3. Why are scans sometimes acceptable?
4. Why does data flow right to left?

---

# Chapter 3 — Statistics and Cardinality Estimation

## Core Idea

Optimizer decisions depend heavily on statistics.

Statistics contain:

* Histogram
* Density information
* Row distribution

## Cardinality Estimation (CE)

CE predicts:

* Number of rows
* Distribution
* Selectivity

Wrong estimates = bad plans.

## Common Causes of Bad Estimates

* Outdated statistics
* Parameter sniffing
* Local variables
* Functions on columns
* Skewed data
* Implicit conversions
* Table variables

## Warning Signs

Estimated Rows != Actual Rows

Especially:

* 1 estimated vs millions actual
* Huge overestimates

## Tuning Techniques

### Technique 1 — Update Statistics

Useful when:

* Data changed heavily
* Plan suddenly regressed

### Technique 2 — Avoid Local Variables

Local variables often force poor estimates.

### Technique 3 — Use Temporary Tables Carefully

Temp tables have stats.
Table variables historically poor estimation.

## Practical Task

1. Create skewed data.
2. Run query.
3. Observe estimate mismatch.
4. Update stats.
5. Compare plans.

## Knowledge Test

1. What is histogram?
2. Why do local variables hurt estimation?
3. Why are stale stats dangerous?
4. Why can implicit conversions hurt plans?

---

# Chapter 4 — Index Access Methods

## Core Operators

### Index Seek

Good selective access.

### Index Scan

Reads many rows/pages.

### Table Scan

Reads entire heap.

### Key Lookup

Lookup back to clustered index.

### RID Lookup

Lookup against heap.

## Important Reality

Scan != always bad.
Seek != always good.

If query returns large percentage of rows:
Scan may be cheaper.

## Key Lookup Danger

Small rows = okay.
Large row count = disaster.

Repeated lookup causes:

* Random I/O
* CPU increase
* Slow performance

## Tuning Techniques

### Technique 1 — Create Covering Index

Add INCLUDE columns.

Goal:
Avoid lookup.

### Technique 2 — Reduce Returned Columns

Avoid:
SELECT *

### Technique 3 — Fix SARGability

Avoid:

* Functions on columns
* Leading wildcard
* Implicit conversions

## Practical Task

1. Create non-covering index.
2. Generate key lookup.
3. Add INCLUDE columns.
4. Compare logical reads.

## Knowledge Test

1. When is scan acceptable?
2. Why are key lookups dangerous?
3. Difference between lookup and seek?
4. What makes predicate non-SARGable?

---

# Chapter 5 — Join Operators

## Nested Loop

Best for:

* Small input
* Indexed lookup

Bad for:

* Large outer input

## Merge Join

Best for:

* Sorted datasets
* Large sets

Requires:

* Sorted input

## Hash Match Join

Best for:

* Large unsorted data
* No useful indexes

Expensive:

* Memory
* CPU

## Tuning Insight

Wrong join often means:
Bad cardinality estimation.

## Red Flags

* Hash spill to tempdb
* Huge memory grant
* Parallel hash joins
* Nested loops with massive rows

## Tuning Techniques

### Technique 1 — Improve Estimates

Fix statistics first.

### Technique 2 — Create Proper Join Indexes

Index join columns.

### Technique 3 — Reduce Row Counts Early

Filter before joins.

## Practical Task

1. Force different join types.
2. Compare IO and CPU.
3. Observe memory grants.

## Knowledge Test

1. Best use case for nested loop?
2. Why are hash joins memory intensive?
3. Why does merge join need sorted input?
4. Why can wrong estimates change join type?

---

# Chapter 6 — Sorting, Aggregation and Spools

## Sort Operator

Expensive because:

* CPU heavy
* Memory heavy
* May spill to tempdb

## Stream Aggregate

Efficient.
Requires ordered input.

## Hash Aggregate

Used for unsorted data.
Consumes more memory.

## Spools

Temporary work tables.

Types:

* Table spool
* Index spool
* Row count spool

Sometimes useful.
Sometimes symptom of poor optimization.

## Tuning Techniques

### Technique 1 — Eliminate Unnecessary Sorts

Use supporting indexes.

### Technique 2 — Watch Spill Warnings

Sort spill = insufficient memory.

### Technique 3 — Reduce Intermediate Rows

Less rows = cheaper sort.

## Practical Task

1. Create ORDER BY query.
2. Observe sort.
3. Add supporting index.
4. Re-test.

## Knowledge Test

1. Why are sorts expensive?
2. Difference between stream and hash aggregate?
3. Why do spills hurt performance?
4. What is spool used for?

---

# Chapter 7 — Execution Plans for Common T-SQL

## Objects and Their Behavior

### Views

Usually expanded into underlying query.

### CTEs

Not materialized automatically.

### Scalar Functions

Historically terrible for performance.

Problems:

* Row-by-row execution
* Serial execution
* Hidden cost

### Table-Valued Functions

Inline TVF better than multi-statement TVF.

### Triggers

Appear inside plans.
Can add hidden cost.

## Tuning Techniques

### Technique 1 — Replace Scalar UDFs

Use:

* Inline logic
* CROSS APPLY
* Inline TVF

### Technique 2 — Inspect Hidden Work

Triggers and functions may hide true cost.

## Practical Task

1. Create scalar UDF.
2. Use in query.
3. Compare with inline logic.
4. Measure CPU.

## Knowledge Test

1. Why are scalar UDFs dangerous?
2. Difference between inline and multi-statement TVF?
3. Why can triggers surprise performance?

---

# Chapter 8 — Parallelism

## Parallel Plan Basics

SQL Server splits work across threads.

Parallelism operators:

* Distribute Streams
* Repartition Streams
* Gather Streams

## CXPACKET / CXCONSUMER

May indicate:

* Skewed workload
* Bad estimates
* Excessive parallelism

Not always a problem.

## Tuning Techniques

### Technique 1 — Reduce Large Scans

Large scans often trigger parallelism.

### Technique 2 — Improve Indexing

Better indexes reduce need for parallel plans.

### Technique 3 — Investigate Cost Threshold

Low threshold may create too many parallel plans.

## Practical Task

1. Compare serial vs parallel plans.
2. Observe exchanges.
3. Measure CPU.

## Knowledge Test

1. Why does SQL Server use parallelism?
2. What causes exchange operators?
3. Why can parallelism increase CPU?

---

# Chapter 9 — Memory Grants and Spills

## Memory Grant

SQL Server allocates memory for:

* Sorts
* Hash joins
* Aggregation

## Problems

Too Small:

* tempdb spill

Too Large:

* concurrency issues
* wasted memory

## Spill Warnings

Critical tuning indicator.

Watch for:

* Sort spills
* Hash spills

## Tuning Techniques

### Technique 1 — Fix Cardinality Errors

Bad estimates → bad grants.

### Technique 2 — Reduce Row Width

Avoid unnecessary columns.

### Technique 3 — Improve Indexes

Reduce data movement.

## Practical Task

1. Force hash join.
2. Generate spill.
3. Compare tempdb usage.

## Knowledge Test

1. What causes memory spills?
2. Why do grants depend on estimates?
3. Why can oversized grants hurt concurrency?

---

# Chapter 10 — Adaptive Query Processing and Batch Mode

## Batch Mode

Processes rows in batches.

Benefits:

* Lower CPU
* Faster analytics

Usually associated with:

* Columnstore
* Modern versions

## Adaptive Joins

Join type decided at runtime.

## Memory Grant Feedback

SQL Server adjusts future grants.

## Tuning Insight

Modern SQL Server can self-correct some issues.

But:
Still requires good indexing and statistics.

## Knowledge Test

1. Why is batch mode faster?
2. What is adaptive join?
3. What does memory grant feedback solve?

---

# Chapter 11 — Query Store and Plan Forcing

## Query Store

Stores:

* Query history
* Runtime stats
* Plans
* Regressions

## Major Uses

* Detect regressions
* Compare plans
* Force stable plan

## Danger of Forced Plans

Data changes.
Old plan may become bad.

## Tuning Techniques

### Technique 1 — Track Regressed Queries

Compare duration and reads.

### Technique 2 — Use Plan Forcing Carefully

Temporary stabilization tool.
Not permanent fix.

## Practical Task

1. Enable Query Store.
2. Create regression.
3. Force old plan.
4. Compare performance.

## Knowledge Test

1. Why is Query Store powerful?
2. When should plan forcing be avoided?
3. Difference between plan cache and Query Store?

---

# Chapter 12 — XML Plans

## Why XML Matters

Graphical plan hides details.
XML exposes everything.

Useful for:

* Automation
* Advanced troubleshooting
* XQuery analysis

## Important XML Data

* Warnings
* Missing indexes
* Runtime stats
* Memory grants
* Spill details

## Tuning Techniques

### Technique 1 — Query Plan Cache Using XQuery

Automate plan analysis.

### Technique 2 — Search for Warnings

Find spills and conversions quickly.

## Knowledge Test

1. Why use XML plans?
2. What information exists only in XML?
3. Why is automation important?

---

# Chapter 13 — Extended Events and Plan Capture

## Extended Events (XE)

Preferred monitoring framework.

Better than SQL Trace because:

* Lower overhead
* Better filtering
* Modern architecture

## Capture Carefully

Execution plans are expensive to capture.

Avoid:

* Broad capture in production
* Unfiltered sessions

## Tuning Techniques

### Technique 1 — Filter Aggressively

Filter by:

* Database
* Duration
* CPU
* Query hash

### Technique 2 — Capture Problem Queries Only

Reduce overhead.

## Practical Task

1. Create XE session.
2. Capture long-running query.
3. Save execution plan.

## Knowledge Test

1. Why is XE preferred over Trace?
2. Why can plan capture hurt performance?
3. Why should XE sessions be filtered?

---

# Chapter 14 — SSMS Tools for Plans

## Important SSMS Features

### Compare Plans

Useful for regression analysis.

### Live Query Stats

Shows runtime progress.

### Operator Properties

Critical for tuning.

### Plan Analysis Warnings

Quick diagnostics.

## Tuning Techniques

### Technique 1 — Compare Before/After Plans

Always validate tuning changes.

### Technique 2 — Use Live Stats for Long Queries

Identify bottleneck operator.

## Practical Task

1. Compare two plans.
2. Identify changed operator.
3. Explain performance difference.

## Knowledge Test

1. Why are plan comparisons useful?
2. When use live query stats?
3. What is most important in operator properties?

---

# Critical Execution Plan Warning Signs

## Immediate Red Flags

| Problem                  | Usually Means                |
| ------------------------ | ---------------------------- |
| Key Lookup + high rows   | Missing covering index       |
| Huge estimate mismatch   | Statistics/cardinality issue |
| Implicit conversion      | Non-SARGable predicate       |
| Hash spill               | Bad memory grant             |
| Sort spill               | Memory pressure              |
| Table scan on huge table | Missing/unused index         |
| Parallel hash join       | Large data movement          |
| Nested loop on huge rows | Bad estimates                |
| Residual predicate       | Inefficient filtering        |
| Warning icons            | Investigate immediately      |

---

# Practical Tuning Mindset

## Always Ask

1. Why did optimizer choose this operator?
2. Was estimate accurate?
3. Is too much data moving?
4. Can rows be reduced earlier?
5. Is indexing aligned with predicates?
6. Is query SARGable?
7. Is memory adequate?
8. Is tempdb involved?
9. Is parallelism helping or hurting?
10. Is this a symptom or root cause?

---

# Weekly Practice Routine

## Daily (30 mins)

1. Open one real execution plan.
2. Explain every operator.
3. Identify largest row movement.
4. Predict bottleneck.
5. Suggest index improvement.

## Weekly Deep Dive

Focus one topic:

* Seeks/scans
* Joins
* Parallelism
* Memory grants
* Statistics
* Query Store

---

# Advanced DBA Exercises

## Exercise 1 — Parameter Sniffing

Create stored procedure.
Run with:

* selective parameter
* non-selective parameter

Compare plans.

---

## Exercise 2 — Spill Analysis

Force large sort/hash.
Observe:

* tempdb usage
* warnings
* runtime impact

---

## Exercise 3 — Lookup Explosion

Generate:

* non-covering index
* large lookup count

Fix using INCLUDE.

---

## Exercise 4 — Bad Cardinality

Use:

* local variables
* skewed data
* outdated statistics

Observe optimizer mistakes.

---

# Final DBA Recall Sheet

## Top 15 Real-World Causes of Bad Plans

1. Missing indexes
2. Bad statistics
3. Parameter sniffing
4. Implicit conversions
5. Scalar UDFs
6. Non-SARGable predicates
7. Excessive key lookups
8. Large scans
9. Poor join order
10. Bad memory grants
11. tempdb spills
12. Parallelism skew
13. Outdated statistics
14. Returning too many columns
15. Poor schema/index design

---

# Golden Rule of Tuning

Execution plans do NOT tell you:

* what to fix

They tell you:

* what SQL Server decided
* where resources are consumed
* where estimates went wrong
* where data movement exploded

Your job:
Understand WHY optimizer made the decision.

That is the real skill.

---

# Recommended Practice Stack

Use:

* AdventureWorks
* StackOverflow database
* Query Store
* Extended Events
* Actual execution plans
* SET STATISTICS IO/TIME

---

# Best Companion Skills

To master execution plans deeply, combine with:

1. SQL Internals
2. Statistics internals
3. Index architecture
4. tempdb internals
5. Memory grants
6. Wait statistics
7. Parallelism internals
8. Query Store
9. Cardinality Estimator versions
10. Parameter sniffing patterns

---

# Final Interview-Level Questions

1. Why would optimizer choose scan over seek?
2. Explain key lookup explosion.
3. Why are estimates critical?
4. Difference between hash and merge join?
5. What causes tempdb spills?
6. Why do implicit conversions hurt performance?
7. Explain parameter sniffing.
8. Why can parallelism slow a query?
9. How does Query Store help tuning?
10. What is the optimizer trying to minimize?

Prompt
I can also help you next with:

Operator-by-operator deep dive
Real execution plan case studies
“How optimizer thinks” mental models
Common anti-patterns
Advanced plan XML analysis
Parameter sniffing mastery
Execution plan troubleshooting playbooks
Daily practice roadmap for 90 days
Mapping this book with Kalen Delaney internals
A visual cheat sheet for all operators
