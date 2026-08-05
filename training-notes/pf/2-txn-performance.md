### Lab 1: Transaction Performance

### Objective

Understand how transaction size affects performance in CockroachDB by comparing a single large transaction with multiple smaller transactions.

---

#### Prerequisites

* CockroachDB cluster is running.
* `perf_lab` database exists.
* `customers` table contains **100,000** rows.

Verify:

```sql
USE perf_lab;

SELECT COUNT(*) FROM customers;
```

**Expected Output**

```text
100000
```

---

# Scenario 1: Large Transaction

Update all customer records in a single transaction.

### Step 1: Start the Transaction

```sql
BEGIN;
```

---

### Step 2: Update All Rows

```sql
UPDATE customers
SET state = 'TS'
WHERE state = 'Telangana';
```

---

### Step 3: Commit the Transaction

```sql
COMMIT;
```

---

### Step 4: Measure Execution Plan

```sql
EXPLAIN ANALYZE
UPDATE customers
SET state = 'Telangana'
WHERE state = 'TS';
```

Observe:

* Planning Time
* Execution Time
* KV Rows Read
* KV Rows Written
* Network Usage
* Contention (if any)

---

# Verify the Update

```sql
SELECT state, COUNT(*)
FROM customers
GROUP BY state
ORDER BY state;
```

---

# Scenario 2: Small Batch Transactions

Instead of updating all matching rows in one transaction, process them in batches.

### Batch 1

```sql
BEGIN;

UPDATE customers
SET state = 'TS'
WHERE customer_id IN
(
    SELECT customer_id
    FROM customers
    WHERE state='Telangana'
    LIMIT 5000
);

COMMIT;
```

Run the above block repeatedly until no rows remain with `state='Telangana'`.

---

### Verify

```sql
SELECT COUNT(*)
FROM customers
WHERE state='Telangana';
```

Expected:

```text
0
```

---

### Compare Performance

| Metric            | Single Large Transaction | Multiple Small Transactions |
| ----------------- | ------------------------ | --------------------------- |
| Transaction Size  | Large                    | Small                       |
| Lock Duration     | Longer                   | Shorter                     |
| Memory Usage      | Higher                   | Lower                       |
| Retry Probability | Higher                   | Lower                       |
| Contention        | Higher                   | Lower                       |
| Commit Time       | Longer                   | Faster per batch            |
| Cluster Impact    | High                     | Low                         |

---

# Monitor During the Lab

Open the CockroachDB DB Console.

Navigate to:

**Observe → SQL Activity**

Monitor:

* Running Statements
* Transaction Latency
* Rows Read
* Rows Written
* Retries (if any)

---

## Production Best Practice

* Keep transactions as short as possible.
* Avoid updating thousands of rows in a single transaction unless necessary.
* Process large data modifications in manageable batches.
* Commit frequently to reduce contention and improve concurrency.

---

## What we Learned

Final Summary:-

* How CockroachDB executes transactions.
* Why large transactions can increase latency and contention.
* How batching updates improves scalability and reduces resource usage.
* How to use `EXPLAIN ANALYZE` and the DB Console to evaluate transaction performance.

