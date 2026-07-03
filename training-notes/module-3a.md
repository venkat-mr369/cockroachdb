### First Observation

You have:

<img width="1053" height="730" alt="image" src="https://github.com/user-attachments/assets/d7eb6b1a-64a4-4952-a952-ca2176deb13a" />


```text
SHOW RANGES FROM TABLE employee;

Total Ranges = 25
```

Earlier, the UI showed **36 replicas**.

Now this command shows **25 ranges** for the `employee` table.

That is **not a contradiction**.

Why?

The **UI counts replicas for the entire database/store**, whereas:

```sql
SHOW RANGES FROM TABLE employee;
```

shows **only the ranges belonging to the `employee` table**.

So there are approximately:

```text
Employee Table        → 25 ranges

Other system tables
(metadata, namespace,
descriptors, jobs, etc.) → 11 ranges

------------------------------------
Total Replicas (UI) → 36
```

---

### Let's understand one row

First row:

```text
<before:/Table/106>  →  /1/20989605
Range ID = 70
Replica = {1}
```

Interpretation:

```text
Employee Table

Primary Key

1

↓

20,989,604

↓

Stored inside

Range 70
```

---

Second row

```text
20989605

↓

24834579

Range71
```

Meaning

```text
Employee IDs

20,989,605

↓

24,834,578

↓

Stored inside Range71
```

---

Third row

```text
24834579

↓

26753106

Range73
```

And so on.

---

### Visual Representation

Your employee table looks like this internally:

```text
Employee Table

1 --------------------20,989,604
        │
        ▼
      Range70

20,989,605 ----------24,834,578
        │
        ▼
      Range71

24,834,579 ----------26,753,105
        │
        ▼
      Range73

26,753,106 ----------30,590,163
        │
        ▼
      Range74

...

97,738,595 ---------- MAX

        │
        ▼
      Range111
```

This is exactly how CockroachDB partitions the table.

---

### Why are they around 2–4 million rows?

This is the important point.

Notice:

```text
Range70

1

↓

20 Million
```

Next

```text
20M

↓

24M
```

Next

```text
24M

↓

26M
```

The ranges are **not equal**.

Why?

Because CockroachDB is **not splitting based on row count**.

It is splitting based on the **encoded KV size** and runtime heuristics.

For example:

Suppose one row occupies:

```text
40 bytes
```

Another row

```text
120 bytes
```

Another row

```text
300 bytes
```

The number of rows per range will therefore vary.

---

### Why didn't it stop at 4 ranges?

This is the biggest misconception.

People think:

```text
1.6 GB

↓

512 MB

↓

4 Ranges
```

No.

The **512 MiB** is a **target size**, not a rule that says "exactly four ranges."


- ✅ Range size (target around 512 MiB)
- ✅ Write load (hot ranges)
- ✅ Existing split points
- ✅ Table/index boundaries
- ✅ Manual splits
- ✅ Load-based splitting
- ✅ Internal balancing

CockroachDB keeps ranges relatively small because:

* Faster Raft replication
* Faster recovery
* Faster rebalancing
* Easier movement to new nodes
* Lower latency
* Better parallelism

Think of it like this:

Instead of

```text
4 large trucks
```

CockroachDB prefers

```text
25 medium trucks
```

Tomorrow if Node2 joins,

it can immediately move some trucks.

---

### Why only one replica?

Notice

```text
Replicas

{1}
```

means

```text
Node1
```

Only.

Because

Replication Factor

```text
RF = 1
```

If RF were 3

You'd see

```text
Range70

Replicas

{1,2,3}
```

---

### What is Range ID?

Notice

```text
70

71

73

74

76
```

Students usually ask

> "Why is 72 missing?"

Excellent question.

Range IDs are **global**.

Example

```text
System Table

Range1

Range2

Range3

...

Employee

Range70

Range71

Range73

...
```

Range72 may belong to

* system.namespace
* jobs
* descriptors
* users

or another object.

Range IDs are **never reused sequentially per table**.

---

### Can we see which table owns each Range?

Yes.

Run

```sql
SELECT range_id, start_key
FROM crdb_internal.ranges
ORDER BY range_id;
```

or

```sql
SHOW RANGES FROM DATABASE ams;
```

This will show ranges for all tables in the database.

---

### Why exactly 25 ranges?

Based on your workload, CockroachDB likely did the following:

1. Started with **one range**.
2. As you inserted **81 million rows**, the range grew.
3. When it became too large (or too busy), it split.
4. The new ranges also grew and split again.
5. This process repeated until the table stabilized at **25 ranges**.

So the process looked like:

```text
Initially

Range70

↓

Split

Range70
Range71

↓

Split Again

Range70
Range71
Range73
Range74

↓

Split Again

...

↓

25 Ranges
```

CockroachDB didn't decide **up front** to create 25 ranges. It created them incrementally as the data and workload grew.

---

#### This is the best way to explain it in interviews

> **CockroachDB does not calculate "Table Size ÷ 512 MB = Number of Ranges." Instead, it starts with a small number of ranges and continuously monitors them. As ranges become too large or too busy, it automatically splits them. The target size is a guideline, not an exact formula. That's why my 1.6 GiB table ended up with 25 ranges instead of just 4. This gives CockroachDB more flexibility to balance load, recover quickly, and redistribute ranges when new nodes are added to the cluster.**

This explanation is accurate and aligns with how CockroachDB's automatic range management works.
