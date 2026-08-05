same `perf_lab` database and demonstrate **transaction contention** and **long-running transactions**, which are key aspects of transaction performance.

---

### Lab 2: Transaction Contention

## Objective

Understand how CockroachDB handles concurrent updates on the same data and observe transaction retries due to contention.

---

## Scenario

Two users attempt to update the same customer record simultaneously.

---

## Step 1: Open Two SQL Sessions

Open **Session 1** and **Session 2**.

---

## Session 1

### Start Transaction

```sql
USE perf_lab;

BEGIN;
```

### Update a Customer

```sql
UPDATE customers
SET city='Bangalore'
WHERE email='user100@gmail.com';
```

**Do not commit yet.**

---

## Session 2

```sql
USE perf_lab;

BEGIN;
```

Attempt to update the same row.

```sql
UPDATE customers
SET city='Hyderabad'
WHERE email='user100@gmail.com';
```

Session 2 will wait or may receive a transaction retry depending on timing and isolation behavior.

---

## Commit Session 1

```sql
COMMIT;
```

---

## Complete Session 2

If required:

```sql
COMMIT;
```

or retry the transaction if CockroachDB returns a retry error.

---

## Verify

```sql
SELECT customer_id, email, city FROM customers WHERE email='user100@gmail.com';
```

---

## Observe

Open the DB Console.

Go to:

**Observe → SQL Activity**

Check:

* Transaction Retries
* Contention Time
* Statement Latency
* Running Transactions

---

## Expected Result

* Only one transaction successfully updates the row first.
* The second transaction waits or retries automatically.
* CockroachDB maintains Serializable isolation.

---

## Learning Outcome

* Transaction contention
* Transaction retries
* Serializable isolation
* Conflict resolution

---

# Lab 3: Long-Running Transactions

## Objective

Understand how long-running transactions affect concurrency and overall database performance.

---

## Step 1: Session 1

```sql
USE perf_lab;

BEGIN;
```

---

Update several rows.

```sql
UPDATE customers
SET state='TEST_STATE'
WHERE city='Mumbai';
```

Leave the transaction open.

Do **not** commit.

---

## Step 2: Session 2

Try reading the same rows.

```sql
SELECT *
FROM customers
WHERE city='Mumbai'
LIMIT 20;
```

Notice that CockroachDB's MVCC allows reads without blocking.

---

Now attempt another update.

```sql
BEGIN;

UPDATE customers
SET state='MH'
WHERE city='Mumbai';

COMMIT;
```

Depending on timing, CockroachDB may wait or retry the transaction to preserve serializable isolation.

---

## Step 3: Commit Session 1

```sql
COMMIT;
```

---

## Verify

```sql
SELECT
state,
COUNT(*)
FROM customers
GROUP BY state
ORDER BY state;
```

---

## Observe

In the DB Console, monitor:

* SQL Activity
* Transaction Latency
* Contention Events
* Active Sessions
* Running Transactions

---

## Expected Result

* Reads continue using MVCC.
* Concurrent writes may wait or retry.
* Long-running transactions increase contention and transaction latency.

---

## Learning Outcome

You will understand:

* Long-running transactions
* MVCC behavior
* Read consistency
* Transaction retries
* Performance impact of keeping transactions open

---

### Summary of Transaction Performance Labs

| Lab       | Topic                       | Concept                                                             |
| --------- | --------------------------- | ------------------------------------------------------------------- |
| **Lab 1** | Large vs Batch Transactions | Compare performance of one large transaction versus smaller batches |
| **Lab 2** | Transaction Contention      | Concurrent updates, contention, retries                             |
| **Lab 3** | Long-Running Transactions   | MVCC, concurrent reads, write conflicts, transaction latency        |

