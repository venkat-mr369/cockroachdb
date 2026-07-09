**CockroachDB internals**, after creating a large `employee` table, you can use the following **system tables**, **system views**, and **built-in commands** to understand the architecture.

> **Note:** Your last query uses `database_name = 'office'`, but your database is `ams`. Replace `'office'` with `'ams'`.

---

### 1. Cluster Architecture

List all nodes in the cluster.

```sql
SHOW CLUSTER SETTING version;
```

```sql
SHOW REGIONS;
```

```sql
SHOW CLUSTER QUERIES;
```

```sql
SHOW CLUSTER SESSIONS;
```

```sql
SELECT *
FROM crdb_internal.gossip_nodes;
```

---

### 2. Node Architecture


View node details.
CockroachDB uses a gossip protocol to distribute cluster metadata among nodes. This includes information such as:

    Which nodes are alive
    Node addresses
    Cluster ID
    Liveness information
    Range and store metadata
    Other system configuration data

```sql
SELECT * FROM crdb_internal.gossip_nodes;
```

```sql
SELECT
node_id,
network,
address,
attrs
FROM crdb_internal.kv_node_status;
```

Storage usage

```sql
SELECT
node_id,
store_id,
capacity,
used
FROM crdb_internal.kv_store_status;
```

---

# 3. Stores

```sql
SELECT *
FROM crdb_internal.kv_store_status;
```

Store capacity

```sql
SELECT
store_id,
node_id,
capacity,
used,
available
FROM crdb_internal.kv_store_status;
```

---

# 4. SQL Layer

Running SQL sessions

```sql
SHOW CLUSTER SESSIONS;
```

Running SQL queries

```sql
SHOW CLUSTER QUERIES;
```

Transactions

```sql
SHOW TRANSACTIONS;
```

---

# 5. Key-Value Layer

Table ID

```sql
SELECT
table_id,
database_name,
schema_name,
name
FROM crdb_internal.tables
WHERE database_name='ams';
```

KV statistics

```sql
SHOW RANGES FROM TABLE employee;
```

---

# 6. DistSQL

Enable distributed execution

```sql
SET DISTSQL = ON;
```

See execution plan

```sql
EXPLAIN ANALYZE
SELECT *
FROM employee
WHERE salary > 50000;
```

Execution diagram

```sql
EXPLAIN (DISTSQL)
SELECT *
FROM employee;
```

---

# 7. Ranges

View all ranges

```sql
SHOW RANGES FROM TABLE employee;
```

Detailed information

```sql
SHOW RANGES FROM INDEX employee@primary;
```

---

# 8. Range Splits

Current split points

```sql
SHOW RANGES FROM TABLE employee;
```

Manual split

```sql
ALTER TABLE employee
SPLIT AT VALUES (500000);
```

Verify

```sql
SHOW RANGES FROM TABLE employee;
```

---

# 9. Range Merges

See merge queue

```sql
SHOW RANGES FROM TABLE employee;
```

Automatic merges happen in the background when adjacent ranges become small. You can observe the reduced number of ranges over time.

---

# 10. Replicas

Replica information

```sql
SHOW RANGES FROM TABLE employee;
```

or

```sql
SELECT *
FROM crdb_internal.ranges;
```

---

# 11. Leaseholders

Current leaseholder

```sql
SHOW RANGES FROM TABLE employee;
```

Look at

```
lease_holder
```

column.

---

# 12. Gossip Protocol

Nodes participating

```sql
SELECT *
FROM crdb_internal.gossip_nodes;
```

Cluster liveness

```sql
SELECT *
FROM crdb_internal.kv_node_liveness;
```

---

# 13. Raft Consensus

Range information

```sql
SELECT *
FROM crdb_internal.ranges;
```

Raft status

```sql
SELECT *
FROM crdb_internal.kv_store_status;
```

Per-node status

```sql
SELECT *
FROM crdb_internal.kv_node_status;
```

---

# 14. Metadata Tables

Databases

```sql
SHOW DATABASES;
```

Tables

```sql
SHOW TABLES;
```

Columns

```sql
SHOW COLUMNS FROM employee;
```

Indexes

```sql
SHOW INDEXES FROM employee;
```

Internal tables

```sql
SELECT *
FROM crdb_internal.tables
WHERE database_name='ams';
```

Namespaces

```sql
SELECT *
FROM system.namespace;
```

Descriptors

```sql
SELECT *
FROM system.descriptor;
```

Users

```sql
SELECT *
FROM system.users;
```

Jobs

```sql
SELECT *
FROM system.jobs;
```

Events

```sql
SELECT *
FROM system.eventlog;
```

Zones

```sql
SHOW ZONE CONFIGURATIONS;
```

---

# 15. Useful Monitoring Queries

Database sizes

```sql
SHOW RANGES FROM DATABASE ams;
```

Table statistics

```sql
SHOW STATISTICS FOR TABLE employee;
```

Table creation

```sql
SHOW CREATE TABLE employee;
```

Query plan

```sql
EXPLAIN ANALYZE
SELECT COUNT(*)
FROM employee;
```

---

## Recommended learning order

1. Cluster Architecture
2. Node Architecture
3. Stores
4. Key-Value Layer
5. SQL Layer
6. DistSQL
7. Ranges
8. Range Splits
9. Replicas
10. Leaseholders
11. Raft Consensus
12. Gossip Protocol
13. Metadata Tables

