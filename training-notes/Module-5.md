### 0. Prepare the 3-Node Lab

On your client/jump host:

```bash
export NODE1=10.10.1.10
export NODE2=10.10.2.10
export NODE3=10.10.3.10
```

Connect to Node 1:

```bash
cockroach sql --insecure --host=$NODE1:26257
```

Check the cluster:

```sql
SELECT node_id, address, sql_address, locality FROM crdb_internal.gossip_nodes ORDER BY node_id;
```

Check existing databases:

```sql
SHOW DATABASES;
```

Select your existing training database:

```sql
USE company
```

Verify your three existing tables:

```sql
SHOW TABLES;

SHOW CREATE TABLE customers;
SHOW CREATE TABLE orders;
SHOW CREATE TABLE employees;
```

Check data:

```sql
SELECT count(*) FROM customers;
SELECT count(*) FROM orders;
SELECT count(*) FROM employees;
```

For all internals commands, first check the version:

```sql
SELECT version();
```

This matters because some `crdb_internal` tables, DB Console pages, and administrative commands vary between CockroachDB versions.

---

# PART 1 — STORAGE ENGINE

### 1. Storage Engine Architecture

CockroachDB's storage architecture can be explained as:

```text
SQL
 |
 v
SQL/KV Requests
 |
 v
Ranges
 |
 v
Replicas
 |
 v
CockroachDB Storage Layer
 |
 v
Pebble
 |
 +---- MemTables
 |
 +---- WAL
 |
 +---- SSTables
 |
 +---- LSM Tree
 |
 v
Disk
```

Each CockroachDB node can have one or more stores.

On **each node**, check the CockroachDB process:

```bash
ps -ef | grep cockroach
```

Look for:

```text
--store=...
```

You can also inspect your systemd unit:

```bash
sudo systemctl cat cockroach
```

Then inspect the store directory.

Example:

```bash
sudo ls -lah /var/lib/cockroach/
```

Do **not** manually modify files in the store directory.

---

### PART 2 — PEBBLE STORAGE ENGINE

### 2. Identify Pebble Storage

CockroachDB uses **Pebble**, an embedded key-value storage engine designed around an LSM-tree architecture.

Conceptually:

```text
CockroachDB Node
      |
      v
   KV Layer
      |
      v
    Pebble
      |
  +---+----------------+
  |                    |
Memory                Disk
  |                    |
MemTable          SSTables
                       |
                   LSM Levels
```

Check node metrics through SQL:

```sql
SHOW CLUSTER SETTING server.time_until_store_dead;
```
server.time_until_store_dead = 5 minutes tells CockroachDB how long an unavailable store must remain unreachable before the cluster treats it as dead for replica recovery and rebalancing decisions. It is not the query failover time. With RF=3, losing one replica still leaves a quorum of two, so affected ranges can generally continue operating while the failed store is unavailable.

To discover available Pebble-related metrics in your version:

```sql
SELECT name FROM crdb_internal.node_metrics WHERE lower(name) LIKE '%pebble%' ORDER BY name;
```
### Pebble Storage Engine Metrics – Description

Command:

```sql
SELECT name FROM crdb_internal.node_metrics WHERE lower(name) LIKE '%pebble%' ORDER BY name;
```

**Purpose:** Displays available **Pebble storage engine-related metrics** on the CockroachDB node. Pebble is CockroachDB's underlying **LSM-based key-value storage engine**.

| Metric                                | Meaning                                                                                |
| ------------------------------------- | -------------------------------------------------------------------------------------- |
| `pebble-compaction.bytes-written`     | Bytes written during **LSM compaction**, where SSTables are reorganized/merged.        |
| `pebble-manifest.bytes-written`       | Bytes written to the Pebble **MANIFEST**, which tracks SSTable and LSM metadata/state. |
| `pebble-memtable-flush.bytes-written` | Bytes written when an in-memory **MemTable is flushed to SSTables on disk**.           |
| `pebble-wal.bytes-written`            | Bytes written to Pebble's **Write-Ahead Log (WAL)** for storage-engine durability.     |
| `pebble-compaction.block-load.*`      | Block I/O activity and latency generated during **compaction**.                        |
| `pebble-get.block-load.*`             | Block I/O activity, cached bytes, and latency during **point reads/gets**.             |
| `pebble-ingest.block-load.*`          | Block I/O activity and latency related to **SSTable ingestion**.                       |

### Simple Flow

```text
                    SQL WRITE
                        │
                        ▼
                   SQL LAYER
                        │
                        ▼
                    KV LAYER
                        │
                        ▼
              Find Target RANGE
                        │
                        ▼
                  LEASEHOLDER
                        │
                        ▼
                RAFT REPLICATION
               /        │        \
              ▼         ▼         ▼
          Replica 1  Replica 2  Replica 3
               \        │        /
                └── RAFT QUORUM ─┘
                        │
                        ▼
              PEBBLE STORAGE ENGINE
                        │
              ┌─────────┴─────────┐
              ▼                   ▼
             WAL               MemTable
       (Durability Log)        (In Memory)
                                  │
                                  │ MemTable Full
                                  ▼
                                FLUSH
                                  │
                                  ▼
                               SSTABLE
                               (On Disk)
                                  │
                                  ▼
                           LSM TREE LEVELS
                                  │
                       ┌──────────┼──────────┐
                       ▼          ▼          ▼
                      L0         L1         L2 ...
                       │          │          │
                       └──────────┼──────────┘
                                  │
                                  ▼
                             COMPACTION
                                  │
                                  ▼
                     Merge / Reorganize SSTables
```

An LSM Tree (Log-Structured Merge-Tree) is a write-optimized data structure where writes are first accumulated in memory (MemTable) and later flushed to immutable disk files (SSTables). Background compaction organizes and merges SSTables across levels to improve storage efficiency and read performance.

1. SQL Layer understands and executes the SQL statement.

2. KV Layer converts the operation into distributed key-value operations and determines the relevant Range.

3. Leaseholder coordinates the request for that range.

4. Raft replicates the write across the range's replicas and requires quorum for consensus/progress.

5. Pebble is the local storage engine used by each replica's store.

6. WAL provides storage-engine durability for pending Pebble writes.

7. MemTable holds recently written data in memory.

8. Flush moves immutable MemTable contents to disk.

9. SSTables are immutable sorted files stored on disk.

10. LSM Tree organizes SSTables into levels such as L0, L1, L2...

11. Compaction merges and reorganizes SSTables between levels.


For LSM-related metrics:

```sql
SELECT name FROM crdb_internal.node_metrics WHERE lower(name) LIKE '%lsm%' ORDER BY name;
```

For storage-related metrics:

```sql 
SELECT name FROM crdb_internal.node_metrics WHERE lower(name) LIKE '%storage%' ORDER BY name;
```

This is safer than assuming a particular metric exists in every CockroachDB release.

---

### PART 3 — MEMTABLES

### 3. Generate Write Activity

Use your existing `employees` table.

First inspect its columns:

```sql
SHOW CREATE TABLE employees;
```

If your existing schema is:

```text
emp_id
emp_name
department
salary
```

generate updates:

```sql
UPDATE employees SET salary = salary + 1 WHERE emp_id BETWEEN 1 AND 10000;
```

Run several times:

```sql
UPDATE employees
SET salary = salary + 1
WHERE emp_id BETWEEN 10001 AND 20000;

UPDATE employees
SET salary = salary + 1
WHERE emp_id BETWEEN 20001 AND 30000;
```

Conceptually, Pebble initially accumulates writes in memory structures while maintaining durability through its WAL.

```text
SQL UPDATE
    |
    v
KV Write
    |
    v
Pebble
  /     \
 v       v
WAL    MemTable
         |
         | Flush
         v
       SSTable
         |
         v
     LSM Levels
```

Important: **MemTables are internal Pebble structures**. You don't query them using SQL like a relational table.

Use metrics to observe their behavior:

```sql
SELECT name, value FROM crdb_internal.node_metrics WHERE lower(name) LIKE '%memtable%' ORDER BY name;
```
**rocksdb.memtable.total-size (~134 MB)** → This can increase or decrease depending on current write activity. When MemTables fill up, Pebble flushes them to SSTables, so memory is reused/released. It does not continuously increase forever.

**pebble-memtable-flush.bytes-written (~875 MB)** → This is a cumulative counter, so it generally keeps increasing as more MemTables are flushed. It typically resets when the relevant node/process metric lifecycle resets, such as after a restart.

SELECT
    name,
    value AS bytes,
    round((value / 1024 / 1024)::DECIMAL, 2) AS mb
FROM crdb_internal.node_metrics
WHERE lower(name) LIKE '%memtable%'
ORDER BY name;

Run this before and after generating heavy writes.

---

### PART 4 — WAL

At the Pebble storage-engine level, the WAL protects writes that have not yet been fully persisted into SSTables.

Generate a transaction:

```sql
BEGIN;

UPDATE employees SET salary = salary + 500 WHERE emp_id = 101;

COMMIT;
```

The simplified path is:

```text
SQL Transaction
       |
       v
Distributed KV Transaction
       |
       v
Raft Proposal
       |
       v
Raft Replicas
       |
       v
Pebble Write
       |
       +---- WAL
       |
       +---- MemTable
       |
       v
SSTables / LSM
```

Be careful when teaching this: **CockroachDB replication uses Raft**, while **Pebble has its own storage-engine WAL**. They are related parts of durability but are not the same thing.

Search metrics:

```sql
SELECT name, value FROM crdb_internal.node_metrics WHERE lower(name) LIKE '%wal%' ORDER BY name;
```

```
SELECT
    name,
    value AS bytes,
    round((value / 1024 / 1024)::DECIMAL, 2) AS mb
FROM crdb_internal.node_metrics
WHERE lower(name) LIKE '%wal%'
  AND (
       lower(name) LIKE '%bytes-written%'
       OR lower(name) LIKE '%bytes_written%'
       OR lower(name) LIKE '%bytes_in%'
      )
ORDER BY name;
```
```
                 SQL WRITE
                     │
                     ▼
                  KV Layer
                     │
                     ▼
               Range Leaseholder
                     │
                     ▼
              RAFT REPLICATION
           "Replicate the change"
                     │
           ┌─────────┼─────────┐
           ▼         ▼         ▼
         Node 1    Node 2    Node 3
           │         │         │
           ▼         ▼         ▼
         Pebble    Pebble    Pebble
           │         │         │
           ▼         ▼         ▼
          WAL       WAL       WAL
           +         +         +
       MemTable  MemTable  MemTable
```
---

### PART 5 — SSTABLES

### 5. SSTable Demo

SSTable means:

```text
Sorted String Table
```

After MemTable flushes, immutable sorted data is represented in SSTables.

Conceptually:

```text
MemTable
   |
   | Flush
   v
SSTable
   |
   v
LSM Level
```

Generate substantial writes using your existing large tables.

For example:

```sql
UPDATE employees SET salary = salary + 1;
```

Then search for SSTable metrics:

```sql
SELECT name, value
FROM crdb_internal.node_metrics
WHERE lower(name) LIKE '%sstable%'
ORDER BY name;
```
```
SELECT name,value AS sstable_count FROM crdb_internal.node_metrics WHERE name = 'rocksdb.num-sstables';
```
You can also inspect Pebble metrics:

```sql
SELECT name, value FROM crdb_internal.node_metrics WHERE lower(name) LIKE '%pebble%' ORDER BY name;
```

For a physical demonstration, identify the store directory from:

```bash
sudo systemctl cat cockroach
```

Then inspect it:

```bash
sudo du -sh <store-directory>
```

Do not delete, rename, or edit Pebble files.

---

### PART 6 — LSM TREE

### 6. LSM Tree Architecture

Pebble uses an LSM-tree design.

```text
                 Writes
                   |
                   v
                MemTable
                   |
                 Flush
                   |
                   v
                 L0
              SST SST SST
                   |
              Compaction
                   |
                   v
                 L1
             SST   SST
                   |
              Compaction
                   |
                   v
                 L2
                   |
                   v
                  ...
```

Generate sustained updates:

```sql
UPDATE employees SET salary = salary + 1 WHERE emp_id % 2 = 0;
```

Then:

```sql
UPDATE employees SET salary = salary + 1 WHERE emp_id % 3 = 0;
```

Then:

```sql
UPDATE employees SET salary = salary + 1 WHERE emp_id % 5 = 0;
```

This creates write activity and new MVCC versions, which eventually contribute to flush and compaction activity.

Search compaction metrics:

```sql
SELECT name, value
FROM crdb_internal.node_metrics
WHERE lower(name) LIKE '%compact%'
ORDER BY name;
```

---

### PART 7 — WRITE PATH

### 7. CockroachDB Distributed Write Path

Execute:

```sql
UPDATE employees
SET salary = salary + 1000
WHERE emp_id = 101;
```

The conceptual distributed write path is:

```text
Client
 |
 v
SQL Gateway
(Node 1)
 |
 v
SQL Execution
 |
 v
KV Request
 |
 v
Find Range
 |
 v
Leaseholder
 |
 v
Raft Proposal
 |
 +----------+----------+
 |          |          |
 v          v          v
Replica 1 Replica 2 Replica 3
 |          |          |
 +----- Quorum ACK -----+
            |
            v
       Commit/Apply
            |
            v
          Pebble
       WAL/MemTable
            |
            v
         SSTables
```

Your SQL gateway does **not** have to be the leaseholder.

Connect through different nodes:

```bash
cockroach sql --insecure --host=$NODE1:26257
```

```sql
UPDATE employees
SET salary = salary + 1
WHERE emp_id = 101;
```

Then Node 2:

```bash
cockroach sql --insecure --host=$NODE2:26257
```

```sql
UPDATE employees
SET salary = salary + 1
WHERE emp_id = 101;
```

CockroachDB routes KV operations to the appropriate range leaseholder.

---

# PART 8 — READ PATH

### 8. CockroachDB Read Path

Execute:

```sql
SELECT *
FROM employees
WHERE emp_id = 101;
```

Conceptually:

```text
Client
 |
 v
SQL Gateway
 |
 v
SQL Execution
 |
 v
KV Read
 |
 v
Range Lookup
 |
 v
Leaseholder / Eligible Replica
 |
 v
Pebble
 |
 +---- MemTable
 |
 +---- SSTables
 |
 v
MVCC Version Selection
 |
 v
Result
```

For a historical read:

```sql
SELECT *
FROM employees
AS OF SYSTEM TIME '-10s'
WHERE emp_id = 101;
```

The read path now needs the MVCC version appropriate to the requested timestamp.

---

# PART 9 — MVCC

### 9. MVCC Demo

Check:

```sql
SELECT *
FROM employees
WHERE emp_id = 101;
```

Update:

```sql
UPDATE employees
SET salary = salary + 100
WHERE emp_id = 101;
```

Wait a few seconds.

Update again:

```sql
UPDATE employees
SET salary = salary + 200
WHERE emp_id = 101;
```

Current:

```sql
SELECT *
FROM employees
WHERE emp_id = 101;
```

Historical:

```sql
SELECT *
FROM employees
AS OF SYSTEM TIME '-10s'
WHERE emp_id = 101;
```

Architecture:

```text
Logical Key
employees/101
     |
     +-- Timestamp T1 → salary 50000
     |
     +-- Timestamp T2 → salary 50100
     |
     +-- Timestamp T3 → salary 50300
                              ^
                              |
                         Latest Version
```

---

# PART 10 — MVCC ARCHITECTURE & VERSION STORAGE

### 10. Generate Multiple Versions

Run:

```sql
UPDATE employees SET salary = salary + 1 WHERE emp_id = 101;
SELECT pg_sleep(2);

UPDATE employees SET salary = salary + 1 WHERE emp_id = 101;
SELECT pg_sleep(2);

UPDATE employees SET salary = salary + 1 WHERE emp_id = 101;
```

Current:

```sql
SELECT *
FROM employees
WHERE emp_id = 101;
```

Historical:

```sql
SELECT *
FROM employees
AS OF SYSTEM TIME '-3s'
WHERE emp_id = 101;
```

Another historical point:

```sql
SELECT *
FROM employees
AS OF SYSTEM TIME '-6s'
WHERE emp_id = 101;
```

Concept:

```text
SQL Row
   |
   v
Encoded KV Key
   |
   +--- MVCC Version @ T1
   |
   +--- MVCC Version @ T2
   |
   +--- MVCC Version @ T3
   |
   v
Pebble Storage
```

---

# PART 11 — GARBAGE COLLECTION

### 11. MVCC Garbage Collection

Old MVCC versions cannot be retained forever.

Check the zone configuration:

```sql
SHOW ZONE CONFIGURATION FOR DATABASE <your_database>;
```

You can inspect configured GC TTL information through zone configuration commands appropriate to your version.

Conceptually:

```text
T1    T2    T3    T4    T5
|-----|-----|-----|-----|
Old                       New

       GC Threshold
            |
            v

Old obsolete MVCC versions
       become eligible
       for garbage collection
```

Do **not** aggressively reduce GC TTL on your main training database just for demonstration. Create a dedicated lab database if you want to experiment with GC settings.

Historical reads also cannot read arbitrarily old data after required MVCC versions have been garbage collected.

---

# PART 12 — CLOSED TIMESTAMPS

### 12. Closed Timestamp Concept

Closed timestamps help CockroachDB determine that no future writes can occur at or below a particular timestamp for relevant ranges, enabling certain consistent reads from follower replicas.

Conceptually:

```text
Time ------------------------------------>

T1       T2       T3       T4       T5
                   ^
                   |
            Closed Timestamp

<= T3
No future write can appear
at/below the closed timestamp
for the relevant range state.

This can enable eligible
follower reads.
```

A practical follower-read demo, where supported:

```sql
SELECT *
FROM employees
AS OF SYSTEM TIME follower_read_timestamp()
WHERE emp_id = 101;
```

You can run this while connected through different nodes.

---

# PART 13 — RANGE MANAGEMENT

### 13. Observe Ranges

CockroachDB automatically divides the keyspace into ranges.

Explore range-related internal tables available in your version:

```sql
SHOW TABLES FROM crdb_internal;
```

Then identify range-related objects:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'crdb_internal'
  AND lower(table_name) LIKE '%range%'
ORDER BY table_name;
```

For a table-level view, depending on your version:

```sql
SHOW RANGES FROM TABLE employees;
```

Try:

```sql
SHOW RANGES FROM TABLE customers;
SHOW RANGES FROM TABLE orders;
SHOW RANGES FROM TABLE employees;
```

This is one of the most useful commands for your range lab.

---

# PART 14 — RANGE SPLITS

### 14. Manual Split Demo

Choose a valid primary-key boundary from `employees`.

For example:

```sql
ALTER TABLE employees SPLIT AT VALUES (500000);
```

Then inspect:

```sql
SHOW RANGES FROM TABLE employees;
```

Before:

```text
Employees Keyspace

|------------------------------|
             Range A
```

After:

```text
|--------------|---------------|
    Range A          Range B
                 ^
                 |
              Split Key
```

If you have approximately 1 million employee rows, this is an excellent visual demo.

CockroachDB can also automatically split ranges as data grows.

---

# PART 15 — RANGE MERGES

### 15. Range Merge Concept

CockroachDB can automatically merge eligible adjacent ranges when they become sufficiently small and conditions permit.

```text
Small Range A    Small Range B

|---------|      |---------|

          |
          v

      Range Merge

          |
          v

|-------------------------|
       Larger Range
```

Unlike the manual `SPLIT AT` demonstration, automatic merge behavior is usually better observed over time through range statistics and DB Console rather than forced on a production-like cluster.

---

# PART 16 — LEASE TRANSFERS

### 16. Leaseholder Demo

Inspect ranges:

```sql
SHOW RANGES FROM TABLE employees;
```

Look for columns identifying leaseholder and replica placement, depending on your CockroachDB version.

The concept is:

```text
Range
 |
 +--- Replica Node 1  <-- Leaseholder
 |
 +--- Replica Node 2
 |
 +--- Replica Node 3
```

Most consistent KV traffic for the range is coordinated through its leaseholder.

CockroachDB can transfer leases:

```text
Before

Node 1 = Leaseholder
Node 2 = Replica
Node 3 = Replica

         |
    Lease Transfer
         v

After

Node 1 = Replica
Node 2 = Leaseholder
Node 3 = Replica
```

Lease transfers may occur for load balancing, locality considerations, node maintenance, or failures.

---

# PART 17 — AUTOMATIC REBALANCING

### 17. Observe Distribution

Use:

```sql
SHOW RANGES FROM TABLE customers;
SHOW RANGES FROM TABLE orders;
SHOW RANGES FROM TABLE employees;
```

Look at which nodes contain replicas and which nodes hold leases.

Concept:

```text
Before

Node 1    Node 2    Node 3
|||||||   ||        ||

          |
          v
   Rebalancing

          |
          v

Node 1    Node 2    Node 3
||||      ||||      ||||
```

CockroachDB's allocator continuously considers replica and lease placement based on constraints, availability, and balancing considerations.

---

# PART 18 — AUTOMATIC SHARDING

### 18. Automatic Distribution

CockroachDB does not require application-managed shards in the traditional sense.

As a table grows:

```text
Table
 |
 v
Range 1
 |
 +-- grows
 |
 v
Split
 |
 +--------+
 |        |
Range 1  Range 2
          |
          +-- grows
          |
          v
         Split
          |
      +---+---+
      |       |
   Range 2  Range 3
```

Then replicas of those ranges can be distributed across nodes.

```text
            Logical Table
                 |
        +--------+--------+
        |        |        |
      Range 1  Range 2  Range 3
        |        |        |
        v        v        v
      Replica Groups Across
        Your Three Nodes
```

This is the CockroachDB concept commonly described as automatic sharding/distribution.

---

# PART 19 — REPLICATION FACTOR

### 19. Check Replica Placement

With your 3-node cluster, the common default replication factor is:

```text
RF = 3
```

But verify rather than assume:

```sql
SHOW ZONE CONFIGURATION FOR RANGE default;
```

Also:

```sql
SHOW RANGES FROM TABLE employees;
```

Concept:

```text
Range 100

Replica 1 → Node 1
Replica 2 → Node 2
Replica 3 → Node 3
```

For RF=3:

```text
3 Replicas
    |
    v
Majority = 2
```

---

# PART 20 — QUORUM

### 20. Quorum Failure Demo

For a 3-replica Raft group:

```text
Node 1  UP
Node 2  UP
Node 3  UP

Quorum = YES
```

Stop one node:

```bash
sudo systemctl stop cockroach
```

Now:

```text
Node 1  UP
Node 2  UP
Node 3  DOWN

2 / 3

Quorum = YES
```

Run from another live node:

```sql
SELECT count(*) FROM customers;
SELECT count(*) FROM orders;
SELECT count(*) FROM employees;
```

Try a write:

```sql
UPDATE employees
SET salary = salary + 1
WHERE emp_id = 101;
```

With the relevant range maintaining quorum, operations can continue.

Do **not** stop a second node during a normal shared training environment.

Conceptually, with RF=3:

```text
Only 1 / 3 available

Quorum = NO

Relevant ranges cannot make
Raft progress for writes.
```

---

# PART 21 — RAFT LEADER ELECTION VS LEASEHOLDER

### 21. Important Distinction

These are **not the same thing**:

```text
Raft Leader
    |
    +-- Internal Raft consensus role
    +-- Coordinates Raft log replication

Leaseholder
    |
    +-- CockroachDB KV range role
    +-- Coordinates many consistent reads/writes
```

Avoid teaching "leaseholder election" as if it were identical to Raft leader election.

CockroachDB tries to colocate the Raft leader and leaseholder when beneficial, but they represent different concepts.

---

# PART 22 — FAILOVER DEMO

### 22. Stop One Node

First verify:

```bash
sudo systemctl status cockroach
```

Stop one node:

```bash
sudo systemctl stop cockroach
```

From another node:

```bash
cockroach sql --insecure --host=$NODE2:26257
```

Run:

```sql
SELECT count(*) FROM customers;

SELECT count(*) FROM orders;

SELECT count(*) FROM employees;
```

Write:

```sql
UPDATE employees
SET salary = salary + 100
WHERE emp_id = 101;
```

The cluster should continue serving ranges that maintain quorum.

Restart:

```bash
sudo systemctl start cockroach
```

Check:

```bash
sudo systemctl status cockroach
```

Verify cluster membership again.

---

# PART 23 — REPLICA RECOVERY

### 23. Node Rejoins

When the stopped node returns:

```text
Node Down
   |
   v
Other Replicas Continue
with Quorum
   |
   v
Node Restarts
   |
   v
Replica State Checked
   |
   v
Raft Log Catch-up
   |
   +-- If manageable divergence
   |
   v
Replica catches up

OR

Snapshot may be required
for sufficiently stale/missing state
```

Start:

```bash
sudo systemctl start cockroach
```

Monitor:

```bash
sudo journalctl -u cockroach -f
```

From SQL:

```sql
SELECT node_id, address, sql_address
FROM crdb_internal.gossip_nodes
ORDER BY node_id;
```

Then:

```sql
SHOW RANGES FROM TABLE employees;
```

Check replica placement again.

---

### Complete Demo Flow

For your **3-node cluster + 3 existing million-row tables**, I would run the class in this sequence:

```text
DAY / LAB 1 — STORAGE INTERNALS

SQL Write
  ↓
Distributed KV
  ↓
Range + Leaseholder
  ↓
Raft
  ↓
Replica
  ↓
Pebble
  ├── WAL
  ├── MemTable
  ├── SSTables
  └── LSM Compaction


DAY / LAB 2 — MVCC

employees row
  ↓
MVCC Key
  ├── Version @ T1
  ├── Version @ T2
  └── Version @ T3
  ↓
Historical Read
  ↓
GC


DAY / LAB 3 — RANGE MANAGEMENT

1M Row Table
  ↓
Ranges
  ↓
Range Splits
  ↓
Replica Placement
  ↓
Leaseholders
  ↓
Automatic Rebalancing


DAY / LAB 4 — REPLICATION

Range
  ↓
RF = 3
  ↓
Replica Node 1
Replica Node 2
Replica Node 3
  ↓
Raft Consensus
  ↓
Quorum


DAY / LAB 5 — FAILURE TEST

3 Nodes UP
  ↓
Stop Node 1
  ↓
2 Nodes UP
  ↓
Quorum Maintained
  ↓
Lease/Raft Leadership Adjustments
  ↓
Queries Continue
  ↓
Writes Continue
  ↓
Start Node 1
  ↓
Replica Catch-up
  ↓
Cluster Healthy
```

