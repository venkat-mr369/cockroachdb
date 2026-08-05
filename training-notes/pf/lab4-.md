### Lab 4: Compare Single-Row vs Multi-Row Transactions

### Objective

Measure the performance difference between small OLTP transactions and large batch transactions.

---

### Scenario

A banking application processes two types of workloads:

* **Online transactions** (updating one customer at a time)
* **Bulk maintenance jobs** (updating thousands of customers)

Determine which approach provides better throughput and lower latency.

---

## Step 1: Check Current Row Count

```sql
USE perf_lab;

SELECT COUNT(*) FROM customers;
```

---

## Step 2: Execute a Single-Row Transaction

```sql
BEGIN;

UPDATE customers
SET city='Delhi'
WHERE email='user100@gmail.com';

COMMIT;
```

Measure execution time.

---

## Step 3: Execute a 100-Row Transaction

```sql
BEGIN;

UPDATE customers
SET city='Hyderabad'
WHERE customer_id IN
(
SELECT customer_id
FROM customers
LIMIT 100
);

COMMIT;
```

Measure execution time.

---

## Step 4: Execute a 10,000-Row Transaction

```sql
BEGIN;

UPDATE customers
SET city='Mumbai'
WHERE customer_id IN
(
SELECT customer_id
FROM customers
LIMIT 10000
);

COMMIT;
```

Measure execution time.

---

## Step 5: Execute a 100,000-Row Transaction

```sql
BEGIN;

UPDATE customers
SET city='Pune';

COMMIT;
```

---

## Step 6: Compare Execution Plans

```sql
EXPLAIN ANALYZE
UPDATE customers
SET city='Chennai'
WHERE city='Pune';
```

Observe:

* Planning Time
* Execution Time
* KV Reads
* KV Writes
* Network Bytes
* Distribution
* Memory Usage

---

## Questions

1. Which transaction completed fastest?
2. Which consumed more resources?
3. Did execution time increase linearly?
4. What happens if another user updates the same rows?

---

## Expected Result

* Single-row updates finish almost instantly.
* Large transactions consume more CPU, memory, and network bandwidth.
* Commit time increases as transaction size grows.
* Larger transactions are more likely to experience contention and retries.

---

## Production Best Practice

For OLTP workloads, prefer small, short-lived transactions. Reserve large updates for scheduled maintenance windows or execute them in batches.

---

# Lab 5: Transaction Retry Analysis

### Objective

Observe CockroachDB's automatic transaction retry mechanism under concurrent write conflicts.

---

## Scenario

Two application servers process the same customer records at the same time.

---

### Session 1

```sql
USE perf_lab;

BEGIN;
```

```sql
UPDATE customers
SET state='KA'
WHERE email='user500@gmail.com';
```

Keep the transaction open.

---

### Session 2

```sql
USE perf_lab;

BEGIN;
```

```sql
UPDATE customers
SET state='MH'
WHERE email='user500@gmail.com';
```

Attempt to commit:

```sql
COMMIT;
```

Depending on timing, CockroachDB may return a retry-related error (or transparently retry when supported by the client).

---

### Commit Session 1

```sql
COMMIT;
```

---

### Retry the Transaction in Session 2

```sql
BEGIN;

UPDATE customers
SET state='MH'
WHERE email='user500@gmail.com';

COMMIT;
```

---

## Verify

```sql
SELECT
email,
state
FROM customers
WHERE email='user500@gmail.com';
```

---

## Monitor in DB Console

Navigate to:

**Observe → SQL Activity**

Review:

* Transaction Retries
* Contention Events
* Statement Execution Time
* Active Transactions

---

## Discussion

Why does CockroachDB retry transactions?

Because CockroachDB provides **Serializable Isolation** using MVCC. When two concurrent transactions modify the same data, the database ensures correctness by allowing one transaction to succeed while the conflicting transaction waits or retries.

---

## Questions

1. Which transaction committed first?
2. Why was the second transaction retried or delayed?
3. How does MVCC help reduce blocking?
4. How would high retry rates affect application performance?

---

## Expected Result

* One transaction commits successfully.
* The conflicting transaction is delayed or retried.
* Data consistency is maintained without sacrificing serializable isolation.
* Applications should be designed to handle transaction retries gracefully.

---

### Transaction Performance Module (Recommended Structure)

1. **Lab 1** – Large Transaction vs Batch Transaction
2. **Lab 2** – Transaction Contention
3. **Lab 3** – Long-Running Transactions
4. **Lab 4** – Single-Row vs Multi-Row Transaction Performance
5. **Lab 5** – Transaction Retry Analysis
