
> **Note:** Some `crdb_internal` views differ by CockroachDB version (v23.x, v24.x, v25.x). If a query isn't available, tell me your version (`SELECT version();`) and I can tailor them.

---

## 1. Cluster Architecture

### Cluster ID

```sql
SELECT cluster_id();
```

### CockroachDB Version

```sql
SELECT version();
```

### List Nodes

```sql
SELECT
node_id,
network,
address,
attrs,
locality
FROM crdb_internal.gossip_nodes;
```

### Node Health

```sql
SELECT *
FROM crdb_internal.kv_node_status;
```

### Store Status

```sql
SELECT *
FROM crdb_internal.kv_store_status;
```

### Cluster Settings

```sql
SHOW ALL CLUSTER SETTINGS;
```

---

# 2. Node Architecture

### Node Build Information

```sql
SELECT
node_id,
build_info
FROM crdb_internal.kv_node_status;
```

### Node Capacity

```sql
SELECT
node_id,
store_id,
capacity,
used,
available
FROM crdb_internal.kv_store_status;
```

### Live Nodes

```sql
SELECT *
FROM crdb_internal.kv_node_liveness;
```

---

# 3. Store Internals

### Store Metrics

```sql
SELECT
store_id,
node_id,
range_count,
lease_count,
capacity,
used,
available
FROM crdb_internal.kv_store_status;
```

### Store Details

```sql
SELECT *
FROM crdb_internal.kv_store_status;
```

---

# 4. SQL Layer

### Running Sessions

```sql
SHOW CLUSTER SESSIONS;
```

### Running Queries

```sql
SHOW CLUSTER QUERIES;
```

### Transactions

```sql
SHOW TRANSACTIONS;
```

### Current Session

```sql
SHOW SESSION;
```

### SQL Statistics

```sql
SELECT *
FROM crdb_internal.statement_statistics;
```

---

# 5. Key-Value Layer

### Table IDs

```sql
SELECT
table_id,
database_name,
schema_name,
name
FROM crdb_internal.tables
WHERE database_name='ams';
```

### Table Descriptor

```sql
SELECT *
FROM system.descriptor;
```

### Namespace

```sql
SELECT *
FROM system.namespace;
```

### Range Distribution

```sql
SHOW RANGES FROM TABLE employee;
```

---

# 6. DistSQL

### Enable DistSQL

```sql
SET DISTSQL = ON;
```

### DistSQL Plan

```sql
EXPLAIN (DISTSQL)
SELECT *
FROM employee
WHERE salary>90000;
```

### Physical Plan

```sql
EXPLAIN ANALYZE
SELECT *
FROM employee;
```

### Vectorized Execution

```sql
EXPLAIN (VEC)
SELECT *
FROM employee;
```

---

# 7. Ranges

### Show All Ranges

```sql
SHOW RANGES FROM TABLE employee;
```

### Range Count

```sql
SELECT count(*)
FROM [SHOW RANGES FROM TABLE employee];
```

### Range Information

```sql
SELECT *
FROM crdb_internal.ranges;
```

### Range Size

```sql
SELECT
range_id,
start_key,
end_key
FROM crdb_internal.ranges;
```

---

# 8. Range Splits

### Before Split

```sql
SHOW RANGES FROM TABLE employee;
```

### Manual Split

```sql
ALTER TABLE employee
SPLIT AT VALUES (5000000);
```

### Verify Split

```sql
SHOW RANGES FROM TABLE employee;
```

### More Splits

```sql
ALTER TABLE employee
SPLIT AT VALUES (10000000);
```

```sql
ALTER TABLE employee
SPLIT AT VALUES (15000000);
```

---

# 9. Range Merges

Observe merges:

```sql
SHOW RANGES FROM TABLE employee;
```

Automatic merge settings:

```sql
SHOW CLUSTER SETTING kv.range_merge.queue_enabled;
```

---

# 10. Replicas

Replica Locations

```sql
SHOW RANGES FROM TABLE employee;
```

Replica Count

```sql
SELECT
range_id,
array_length(replicas,1)
FROM crdb_internal.ranges;
```

Replica Details

```sql
SELECT *
FROM crdb_internal.ranges;
```

---

# 11. Leaseholders

Current Leaseholder

```sql
SHOW RANGES FROM TABLE employee;
```

Lease Distribution

```sql
SELECT
lease_holder,
count(*)
FROM [SHOW RANGES FROM TABLE employee]
GROUP BY lease_holder;
```

---

# 12. Gossip Protocol

Nodes

```sql
SELECT *
FROM crdb_internal.gossip_nodes;
```

Node Liveness

```sql
SELECT *
FROM crdb_internal.kv_node_liveness;
```

Localities

```sql
SELECT
node_id,
locality
FROM crdb_internal.gossip_nodes;
```

---

# 13. Raft Consensus

All Raft Ranges

```sql
SELECT *
FROM crdb_internal.ranges;
```

Replica Information

```sql
SHOW RANGES FROM TABLE employee;
```

Raft Leaseholders

```sql
SELECT
range_id,
lease_holder
FROM [SHOW RANGES FROM TABLE employee];
```

---

# 14. Metadata Tables

Databases

```sql
SHOW DATABASES;
```

Schemas

```sql
SHOW SCHEMAS;
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

Constraints

```sql
SHOW CONSTRAINTS FROM employee;
```

Statistics

```sql
SHOW STATISTICS FOR TABLE employee;
```

Create Statement

```sql
SHOW CREATE TABLE employee;
```

Zones

```sql
SHOW ZONE CONFIGURATIONS;
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

Comments

```sql
SELECT *
FROM system.comments;
```

Role Members

```sql
SELECT *
FROM system.role_members;
```

Privileges

```sql
SHOW GRANTS;
```

---

# 15. Performance & Troubleshooting

Top Slow Statements

```sql
SELECT *
FROM crdb_internal.statement_statistics
ORDER BY max_latency DESC;
```

Current Locks

```sql
SHOW CLUSTER LOCKS;
```

Current Transactions

```sql
SHOW CLUSTER TRANSACTIONS;
```

Table Statistics

```sql
SHOW STATISTICS FOR TABLE employee;
```

Execution Plan

```sql
EXPLAIN ANALYZE
SELECT *
FROM employee
WHERE emp_id=500000;
```

Index Usage

```sql
EXPLAIN
SELECT *
FROM employee
WHERE emp_id=100;
```

---

## For a DBA or CockroachDB administrator course

If your goal is to teach CockroachDB internals, I recommend expanding this into **100+ hands-on labs**, including:

* Cluster architecture labs
* KV layer internals
* Range and replica movement
* Leaseholder transfers
* Raft leader elections
* Node failures and recovery
* Rebalancing
* Zone configurations
* Multi-region architecture
* Backup and restore internals
* SQL optimizer and DistSQL execution
* Performance troubleshooting using internal system tables

This would provide a much more complete, enterprise-level curriculum than just a list of system views.
