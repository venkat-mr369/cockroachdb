Yes. I'll continue based on your existing CockroachDB lab environment.

### Existing Lab Environment

| Node  | IP             | Role                 |
| ----- | -------------- | -------------------- |
| Node1 | **10.10.1.10** | Initial Cluster Node |
| Node2 | **10.10.2.10** | Cluster Member       |
| Node3 | **10.10.3.10** | Cluster Member       |

Version:

```
CockroachDB v25.2.2
```

Mode:

```
--insecure
```

Now we'll continue from the administration labs.

---

# Lab 13 : Cluster Initialization & Settings

Although the cluster is already initialized, every DBA should verify the initialization and important cluster settings.

### Step 1 Verify Cluster Version

```sql
SHOW CLUSTER SETTING version;
```

Example

```
25.2
```

---

### Step 2 Verify Cluster Organization

```sql
SHOW CLUSTER SETTING cluster.organization;
```

Set organization

```sql
SET CLUSTER SETTING cluster.organization='DBA Centre';
```

Verify

```sql
SHOW CLUSTER SETTING cluster.organization;
```

---

### Step 3 Check Cluster ID

```sql
SELECT cluster_id FROM crdb_internal.cluster_id;
```

---

### Step 4 Verify Nodes

```sql
SHOW NODES;
```

Expected

```
node_id
address
locality
is_live
started_at
build
```

---

### Step 5 Check Cluster Settings

```sql
SHOW ALL CLUSTER SETTINGS;
```

Useful settings

```sql
SHOW CLUSTER SETTING kv.range_merge.queue_enabled;

SHOW CLUSTER SETTING kv.snapshot_rebalance.max_rate;

SHOW CLUSTER SETTING server.time_until_store_dead;

SHOW CLUSTER SETTING sql.defaults.distsql;

SHOW CLUSTER SETTING sql.defaults.vectorize;
```

---

### Step 6 Verify Cluster Regions

```sql
SHOW REGIONS;
```

If geo-partitioning is not configured

```
No rows
```

---

### Step 7 Verify Node Liveness

```sql
SELECT *
FROM crdb_internal.gossip_liveness;
```

---

### Step 8 Verify Cluster Database

```sql
SHOW DATABASES;
```

---

## Outcome

✔ Cluster initialized

✔ Nodes healthy

✔ Version verified

✔ Cluster settings verified

---

# Lab 14 : Cluster Configuration

### Check Locality

```sql
SHOW NODES;
```

Look at

```
locality
```

---

### Replication Zones

```sql
SHOW ZONE CONFIGURATIONS;
```

---

### Check Number of Replicas

```sql
SHOW RANGES FROM TABLE customers;
```

Look for

```
replicas
```

---

### Check Leaseholders

```sql
SHOW RANGES FROM TABLE orders;
```

Notice

```
lease_holder
```

---

### Store Information

```sql
SELECT *
FROM crdb_internal.kv_store_status;
```

---

### Check Capacity

```sql
SELECT
node_id,
capacity,
available
FROM crdb_internal.kv_store_status;
```

---

### Check Cluster Settings

```sql
SHOW CLUSTER SETTINGS;
```

---

## Outcome

Understand

* Replication
* Leaseholders
* Store Capacity
* Zone Configuration

---

# Lab 15 : Node Management

Current Nodes

```sql
SHOW NODES;
```

Node Status

```sql
SELECT
node_id,
is_live,
address
FROM crdb_internal.gossip_liveness;
```

Cluster Health

```sql
SHOW CLUSTER QUERIES;
```

Sessions

```sql
SHOW CLUSTER SESSIONS;
```

Store Status

```sql
SELECT *
FROM crdb_internal.kv_store_status;
```

---

# Lab 16 : Adding a New Node (10.10.4.10)

Assume

```
Hostname

crdb-node4

IP

10.10.4.10
```

## Install CockroachDB

Copy the CockroachDB binary to the new server (same version as existing cluster).

Verify:

```bash
cockroach version
```

---

## Start Node4

```bash
cockroach start \
--insecure \
--advertise-addr=10.10.4.10 \
--listen-addr=10.10.4.10 \
--http-addr=10.10.4.10:8080 \
--store=/data/cockroach \
--join=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257 \
--background
```

---

Verify

```sql
SHOW NODES;
```

Expected

```
Node1

Node2

Node3

Node4
```

---

Check Rebalancing

```sql
SHOW RANGES;
```

or

```sql
SELECT *
FROM crdb_internal.kv_store_status;
```

Observe ranges automatically moving to Node4 over time.

---

# Lab 17 : Removing a Node

Suppose Node4 is no longer required.

First verify

```sql
SHOW NODES;
```

Never stop the process immediately. Use decommissioning.

---

# Lab 18 : Node Decommission

Find Node ID

```sql
SHOW NODES;
```

Example

```
Node4

node_id = 4
```

Decommission

```bash
cockroach node decommission 4 \
--insecure \
--host=10.10.1.10:26257
```

Watch progress

```bash
cockroach node status \
--insecure \
--host=10.10.1.10:26257
```

Or in SQL

```sql
SHOW NODES;
```

Wait until

```
is_live = false

is_decommissioning = false

membership = decommissioned
```

CockroachDB automatically transfers replicas before completing the operation.

---

# Lab 19 : Node Recommission

If the node has not been fully decommissioned, recommission it:

```bash
cockroach node recommission 4 \
--insecure \
--host=10.10.1.10:26257
```

Verify

```sql
SHOW NODES;
```

Observe that the node rejoins and ranges rebalance automatically.

---

# Lab 20 : Cluster Upgrade

Current Version

```bash
cockroach version
```

Cluster Version

```sql
SHOW CLUSTER SETTING version;
```

Upgrade Process

```
Backup

↓

Upgrade Node1

↓

Wait

↓

Upgrade Node2

↓

Wait

↓

Upgrade Node3

↓

Finalize Cluster Version
```

After all binaries are upgraded:

```sql
SHOW CLUSTER SETTING version;
```

Confirm that the cluster version has been finalized.

---

# Lab 21 : Cluster Health

Nodes

```sql
SHOW NODES;
```

Ranges

```sql
SHOW RANGES;
```

Running Queries

```sql
SHOW CLUSTER QUERIES;
```

Sessions

```sql
SHOW CLUSTER SESSIONS;
```

Jobs

```sql
SHOW JOBS;
```

Store Capacity

```sql
SELECT *
FROM crdb_internal.kv_store_status;
```

Monitor for:

* Dead nodes
* Under-replicated ranges
* High disk usage
* High CPU
* High latency
* Failed jobs

---

# Lab 22 : Cluster Diagnostics (Manage Long-Running Queries)

View Active Queries

```sql
SHOW CLUSTER QUERIES;
```

Example output

```
query_id
node_id
username
start
sql
```

View Active Sessions

```sql
SHOW CLUSTER SESSIONS;
```

Cancel a Query

```sql
CANCEL QUERY '<query_id>';
```

Cancel a Session

```sql
CANCEL SESSION '<session_id>';
```

Find Expensive Statements

```sql
SELECT *
FROM crdb_internal.cluster_execution_insights;
```

Find Slow Statements

```sql
SELECT *
FROM crdb_internal.statement_statistics;
```

Typical issues to investigate:

* Full table scans
* Missing indexes
* Lock contention
* Large sort operations
* Hot ranges
* High network latency
* Skewed leaseholder distribution

---

These labs continue directly from your existing 3-node CockroachDB cluster (`10.10.1.10`, `10.10.2.10`, `10.10.3.10`) and add realistic production administration scenarios such as adding `10.10.4.10`, decommissioning/recommissioning nodes, performing rolling upgrades, checking cluster health, and diagnosing long-running queries.
