Great question. This is an important CockroachDB concept.

## What is `SET DISTSQL = ON;`?

```sql
SET DISTSQL = ON;
```

This tells the SQL session:

> **"Whenever possible, execute SQL queries using the Distributed SQL (DistSQL) engine instead of running everything on a single node."**

CockroachDB is a distributed database. Your data is spread across multiple nodes, so it can process parts of a query on those nodes in parallel.

---

# Why is it needed?

Imagine a 3-node cluster.

```
               CockroachDB Cluster

        +-----------+   +-----------+   +-----------+
        |  Node 1   |   |  Node 2   |   |  Node 3   |
        | Range 1   |   | Range 2   |   | Range 3   |
        +-----------+   +-----------+   +-----------+

Employee Table

1 - 3M          3M - 6M          6M - 10M
```

Suppose you run:

```sql
SELECT COUNT(*)
FROM employee;
```

with 10 million rows.

---

## Case 1: DistSQL OFF

If the optimizer chooses a local plan, one node may do most of the work.

```
            Client

              |

           Node 1

      Reads everything

              |

        Returns result
```

Node 1 ends up requesting data from the other nodes and doing more centralized processing.

---

## Case 2: DistSQL ON

Each node processes its own data.

```
              Client

                 |

            Gateway Node

        /        |        \

    Node1     Node2     Node3

 Count()     Count()    Count()

        \        |        /

         Final Aggregation

             Result
```

For example:

* Node 1 counts 3,000,000 rows
* Node 2 counts 3,000,000 rows
* Node 3 counts 4,000,000 rows

The gateway node simply adds those partial counts:

```
3M + 3M + 4M = 10M
```

This parallel execution is usually much faster for large scans.

---

# What happens internally?

When DistSQL is used, the optimizer builds a **physical distributed execution plan**.

For:

```sql
SELECT AVG(salary)
FROM employee;
```

each node computes a partial result:

```
Node 1

SUM = 120000000

COUNT = 3000000
```

```
Node 2

SUM = 130000000

COUNT = 3000000
```

```
Node 3

SUM = 170000000

COUNT = 4000000
```

The gateway combines them:

```
Total SUM
----------
420000000

Total COUNT
-----------
10000000

AVG = SUM / COUNT
```

Only the small partial results travel across the network instead of millions of rows.

---

# How can you verify DistSQL?

Run:

```sql
SET DISTSQL = ON;

EXPLAIN (DISTSQL)
SELECT COUNT(*)
FROM employee;
```

You'll see a distributed plan showing processors on multiple nodes and the data flow between them.

You can also run:

```sql
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM employee;
```

The plan will indicate whether the execution was distributed and include execution statistics.

---

# Is `SET DISTSQL = ON` always required?

**Usually, no.**

Modern CockroachDB versions use the cost-based optimizer to decide automatically whether a distributed plan is beneficial.

The session setting is mainly useful for:

* Learning and demonstrations
* Testing distributed execution
* Comparing distributed vs. local plans
* Troubleshooting query execution

---

# DistSQL modes

You can inspect the current mode:

```sql
SHOW DISTSQL;
```

Common modes include:

* `AUTO` – The optimizer decides (this is the default in modern versions).
* `ON` – Prefer distributed execution whenever possible.
* `OFF` – Disable distributed execution for the session.

---

### For your CockroachDB course

A very effective demo is:

1. Create a 3-node cluster.
2. Insert 30 million rows.
3. Run:

   ```sql
   EXPLAIN ANALYZE SELECT COUNT(*) FROM employee;
   ```
4. Observe the distributed plan.
5. Compare with a session where DistSQL is set differently (if supported by your version).
6. Explain how ranges, replicas, leaseholders, and DistSQL processors work together to execute the query.

This helps students connect **ranges**, **leaseholders**, **Raft**, and **DistSQL** into one complete picture of how CockroachDB executes SQL across a cluster.
