understand CockroachDB internals. In **3-node CockroachDB cluster**, 
load **1 million rows into three tables**, then perform the following demos. 

Each lab demonstrates one internal component.

We'll use:

* Node1: 10.0.1.10
* Node2: 10.0.2.10
* Node3: 10.0.3.10

###### Lab 1 - Create Database

```sql
CREATE DATABASE internals_lab;

USE internals_lab;
```

---

###### Lab 2 - Create Tables

```sql
CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_name STRING,
    city STRING,
    created_at TIMESTAMP DEFAULT now()
);

CREATE TABLE products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_name STRING,
    price DECIMAL
);

CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID,
    product_id UUID,
    quantity INT,
    order_date TIMESTAMP DEFAULT now()
);
```

---

###### Lab 3 - Load 1 Million Rows

Customers

```sql
INSERT INTO customers(customer_name,city)
SELECT
'Customer-'||g,
'City-'||(random()*100)::INT
FROM generate_series(1,1000000) g;
```

Products

```sql
INSERT INTO products(product_name,price)
SELECT
'Product-'||g,
(random()*10000)::DECIMAL
FROM generate_series(1,1000000) g;
```

Orders

```sql
INSERT INTO orders(customer_id,product_id,quantity)
SELECT
(
SELECT customer_id
FROM customers
ORDER BY random()
LIMIT 1
),
(
SELECT product_id
FROM products
ORDER BY random()
LIMIT 1
),
(random()*10)::INT
FROM generate_series(1,1000000);
```

---

## Demo 1 — SQL Layer

Understand how SQL is parsed into KV operations.

Run

```sql
EXPLAIN SELECT * FROM customers WHERE city='City-50';
```

Observe

* Scan
* Filter
* Cost
* Estimated rows

Questions

Where did SQL go after parsing?

---

## Demo 2 — DistSQL

Run

```sql
SET DISTSQL = ALWAYS;
```

Now

```sql
EXPLAIN ANALYZE

SELECT
city,
count(*)
FROM customers
GROUP BY city;
```

Observe

Multiple processors

Streams

Distributed execution

Questions

Which nodes executed work?

How many processors?

---

## Demo 3 — Key Value Layer

Every SQL row becomes KV pairs.

Run

```sql
SHOW RANGES FROM TABLE customers;
```

Observe

Range IDs

Start Key

End Key

Replica locations

Questions

How many ranges were created?

---

## Demo 4 — Ranges

Run

```sql
SHOW RANGES FROM TABLE orders;
```

Observe

Multiple ranges.

Now insert another million rows.

Observe

Number of ranges increases.

Questions

Why?

---

## Demo 5 — Automatic Range Split

Current threshold is roughly 512 MB.

Check

```sql
SHOW RANGES FROM TABLE customers;
```

Insert another million rows.

Run again

```sql
SHOW RANGES FROM TABLE customers;
```

Observe

Range count increased.

Questions

Why did Cockroach split?

---

## Demo 6 — Manual Split

Split at key.

```sql
ALTER TABLE customers
SPLIT AT
VALUES(gen_random_uuid());
```

Check

```sql
SHOW RANGES FROM TABLE customers;
```

Observe

New range.

---

## Demo 7 — Range Merge

Delete almost everything.

```sql
DELETE FROM customers;
```

Wait.

Observe

Background merge.

Run

```sql
SHOW RANGES FROM TABLE customers;
```

Questions

Did ranges reduce?

---

## Demo 8 — Replicas

Run

```sql
SHOW RANGES FROM TABLE customers;
```

Observe

Replicas

Node IDs

Leaseholder

Normally

```
Range 5

Replica1 Node1

Replica2 Node2

Replica3 Node3
```

Questions

Why three replicas?

---

## Demo 9 — Leaseholders

Run

```sql
SHOW RANGES FROM TABLE customers;
```

Observe

Lease Holder

Example

```
Range 45

Leaseholder

Node2
```

Now

Stop Node2.

```bash
sudo systemctl stop cockroach
```

Run again.

Observe

Leaseholder moved.

Questions

How long?

---

## Demo 10 — Raft Consensus

Find leader.

```sql
SHOW RANGES FROM TABLE orders;
```

Stop leader node.

Insert

```sql
INSERT INTO orders(...)
```

Observe

No data loss.

Leader changes.

Questions

Who elected new leader?

---

## Demo 11 — Gossip Protocol

On every node

```
http://node-ip:8080
```

Observe

Cluster nodes

Liveness

Capacity

Network

Stop one node.

Observe

Marked dead.

Restart.

Observe

Back alive.

---

## Demo 12 — Metadata Tables

Run

```sql
SHOW RANGES;
```

Now

```sql
SELECT *
FROM crdb_internal.tables;
```

Run

```sql
SELECT *
FROM crdb_internal.ranges;
```

Observe

Metadata

Range IDs

Leaseholder

Replicas

---

## Demo 13 — Distributed Join

Run

```sql
SET DISTSQL=ALWAYS;
```

```sql
EXPLAIN ANALYZE

SELECT
c.customer_name,
p.product_name,
o.quantity
FROM customers c
JOIN orders o
ON c.customer_id=o.customer_id
JOIN products p
ON o.product_id=p.product_id
LIMIT 1000;
```

Observe

Distributed Join

Hash Join

Processors

Network Streams

---

## Demo 14 — Hot Range

Repeatedly update one row.

```sql
UPDATE customers
SET city='HYD'
WHERE customer_id='...';
```

Observe

Same leaseholder handles writes.

Questions

Why does one node become hot?

---

## Demo 15 — Transaction Demo

Open Session 1

```sql
BEGIN;

UPDATE customers
SET city='Delhi'
WHERE customer_id='...';
```

Do not commit.

Session 2

```sql
SELECT *
FROM customers
WHERE customer_id='...';
```

Observe MVCC behavior.

Commit.

Observe changes become visible.

---

## Demo 16 — Node Failure Demo

Stop Node3.

```bash
sudo systemctl stop cockroach
```

Run

```sql
INSERT INTO customers(customer_name,city)
VALUES('Venkat','Hyderabad');
```

Works because quorum (2 of 3 replicas) is still available.

Start Node3.

```bash
sudo systemctl start cockroach
```

Watch it catch up.

---

###### Final Summary

1. Create the database and three tables.
2. Load 1 million rows into each table.
3. Use `EXPLAIN` to see how SQL is planned (SQL Layer).
4. Enable `DISTSQL=ALWAYS` and run aggregations and joins to observe distributed execution.
5. Inspect `SHOW RANGES FROM TABLE ...` to understand the Key-Value layer and range distribution.
6. Insert additional data to trigger automatic range splits, and perform a manual split to compare.
7. Delete most data and observe background range merges over time.
8. Examine replicas and leaseholders, then stop a node to watch leaseholder movement and automatic recovery.
9. Demonstrate Raft by stopping the leader replica and continuing writes with the remaining quorum.
10. Use the DB Console (`:8080`) to observe node liveness, replication, and cluster health (Gossip/liveness information).
11. Query `crdb_internal` views to inspect metadata about tables, ranges, replicas, and leases.
12. Perform distributed joins, MVCC transaction tests, and a node-failure scenario to tie all internals together.


