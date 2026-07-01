# Module 3: CockroachDB Architecture

**Setup context:** `node1` (`oel9-n1`) is currently running as a `start-single-node` instance. `node2` and `node3` will join later to form a proper 3-node cluster. This doc has concept notes + verification commands you can run **now on node1 alone**, and a separate section of commands to run **after node2/node3 join**.

---

## 1. Distributed SQL Architecture

CockroachDB is a distributed SQL database: data is automatically split, replicated, and distributed across nodes, but presents a single logical SQL interface to clients (like talking to one big Postgres-compatible database).

Key idea: **any node can serve any query** — there's no single "master" node for reads/writes. A client can connect to any node, and that node coordinates with others (via KV layer + Raft) to fetch/write data, regardless of where the data physically lives.

Layers (top to bottom):
```
SQL Layer        <- parses/plans/executes SQL, talks to KV via SQL-to-KV mapping
Transaction Layer <- ACID guarantees, MVCC, timestamps
Distribution Layer (DistSender) <- routes KV requests to the right range/replica
Replication Layer <- Raft consensus across replicas
Storage Layer     <- Pebble (LSM-tree) key-value storage engine on disk
```

---

## 2. Node Architecture

A **node** = one running `cockroach` process (one OS process per machine/VM, usually).

Each node contains:
- One or more **stores** (each store = one directory/disk, backed by Pebble)
- A **KV server** (handles Raft, range routing)
- A **SQL server / gateway** (accepts client SQL connections)
- Internal gossip client (talks to other nodes)

A node is identified by a **Node ID** (integer, assigned on first join, permanent for that node's lifetime).

### Commands to check node1's own architecture right now
```bash
# Confirm the service is up
sudo systemctl status cockroach

# Node's own status (works even single-node)
cockroach node status --certs-dir=/var/lib/cockroach/certs --host=localhost

# Detailed node info (ID, address, build, locality, etc.)
cockroach node status --certs-dir=/var/lib/cockroach/certs --host=localhost --all

# Check which store directories node1 is using
sudo ls -l /var/lib/cockroach/

# Confirm listening ports (SQL=26257, RPC/Admin UI=8080 by default)
sudo ss -tlnp | grep cockroach

# Check cockroach version/build info
cockroach version
```

---

## 3. Cluster Architecture

A **cluster** = a group of nodes that have been joined together (via `--join` flags) and share the same Cluster ID. All nodes in a cluster gossip cluster metadata, participate in Raft groups together, and jointly own the full keyspace.

- Cluster ID is generated once, at `cockroach init` (or auto for single-node), and never changes.
- Adding node2/node3 later means starting them with `--join=node1_ip:26257` (and node1 also updated to know about them), then optionally running `cockroach init` only if the cluster wasn't already initialized.

### Commands to check cluster identity on node1 (pre-join)
```bash
# Cluster ID
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT crdb_internal.cluster_id();"

# Confirm this is (still) a single-node cluster
cockroach node status --certs-dir=/var/lib/cockroach/certs --host=localhost
# -> should show only 1 row right now
```

---

## 4. Stores

A **store** = one storage directory on disk, mapped to a single physical disk in production (avoid multiple stores on the same disk). Configured via `--store=path` at startup (can specify multiple `--store` flags for multiple disks per node).

Each store:
- Uses the **Pebble** engine (LSM-tree based, RocksDB successor)
- Holds many **replicas** of various **ranges**
- Has its own store ID, unique cluster-wide

### Commands
```bash
# Confirm node1's store path (from the systemd unit / ps)
ps aux | grep cockroach
cat /etc/systemd/system/cockroach.service | grep store

# Disk usage of the store
sudo du -sh /var/lib/cockroach/*

# Store-level details via SQL introspection
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT * FROM crdb_internal.kv_store_status;"
```

---

## 5. Key-Value (KV) Layer

Underneath SQL, everything is stored as ordered key-value pairs. SQL tables/indexes/rows are encoded into keys (table ID + index ID + primary key values) and values (encoded column data). This is what lets CockroachDB shard/distribute/replicate data generically, without knowing "SQL semantics" at that layer.

### Command to see KV encoding conceptually
```bash
# See how a table maps into ranges/keys
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "CREATE TABLE IF NOT EXISTS demo.t1 (id INT PRIMARY KEY, val STRING);"

cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SHOW RANGES FROM TABLE demo.t1;"
```

---

## 6. SQL Layer

Turns SQL text into a query plan, which gets translated into KV operations. Fully distributed: SQL layer runs on whichever node the client connected to (the "gateway node"), and can push down execution to other nodes via DistSQL when beneficial.

### Commands
```bash
# Connect interactively
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost

# Inside SQL shell: view query plan
EXPLAIN SELECT * FROM demo.t1 WHERE id = 1;

# Distributed plan info
EXPLAIN (DISTSQL) SELECT * FROM demo.t1;
```

---

## 7. DistSQL (Distributed SQL Execution)

When a query needs data from many ranges/nodes (e.g., large scans, joins, aggregations), CockroachDB breaks it into a **physical plan** with processors that run in parallel across nodes, streaming partial results back to the gateway node for final assembly. This avoids pulling all data to one node first.

### Commands
```sql
-- Check whether a query used the distributed engine
EXPLAIN ANALYZE SELECT count(*) FROM demo.t1;

-- Cluster setting controlling distsql usage
SHOW CLUSTER SETTING sql.defaults.distsql;
```

---

## 8. Ranges

CockroachDB splits the entire keyspace into contiguous chunks called **ranges** (default target size ~512 MiB, configurable). Every range is independently replicated (default RF=3) and has its own Raft consensus group.

### Commands
```sql
-- List ranges cluster-wide
SELECT * FROM crdb_internal.ranges LIMIT 20;

-- Range count summary
SELECT count(*) FROM crdb_internal.ranges;
```
```bash
# Via CLI
cockroach node status --certs-dir=/var/lib/cockroach/certs --host=localhost --ranges
```

---

## 9. Range Splits

When a range grows too large (or has a manually configured split point), CockroachDB automatically splits it into two smaller ranges. Splits can also be forced manually for load isolation/testing.

### Commands
```sql
-- Manually split a range at a given key (example)
ALTER TABLE demo.t1 SPLIT AT VALUES (500);

-- Check split status
SHOW RANGES FROM TABLE demo.t1;
```
```bash
# Cluster setting for default range max size
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SHOW CLUSTER SETTING kv.range_split.by_load_enabled;"
```

---

## 10. Range Merges

The inverse of splitting: when adjacent ranges shrink (e.g., after deletes), CockroachDB automatically merges them back together to reduce overhead, as long as the combined size stays under the split threshold.

### Commands
```sql
-- Cluster setting controlling merges
SHOW CLUSTER SETTING kv.range_merge.queue_enabled;
```

---

## 11. Replicas

Each range has multiple **replicas** (copies), by default 3 (`num_replicas` in zone configs), placed on different nodes for fault tolerance. Replicas of a range form a Raft group.

### Commands (meaningful once node2/node3 exist; queryable now too)
```sql
SELECT range_id, start_pretty, replicas, lease_holder
FROM crdb_internal.ranges LIMIT 20;
```
```bash
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SHOW ZONE CONFIGURATION FOR RANGE default;"
```

---

## 12. Leaseholders

Among a range's replicas, one is elected the **leaseholder** — the replica that serves all reads (without needing Raft consensus for reads) and coordinates writes for that range during its lease period. Leases are time-bound and can move between replicas (e.g., for load balancing or node failure).

### Commands
```sql
SELECT range_id, lease_holder, replicas FROM crdb_internal.ranges LIMIT 20;
```
```bash
# Web UI equivalent (once you have access): http://<node1-ip>:8080/#/reports/range/<range_id>
```

---

## 13. Gossip Protocol

Nodes exchange cluster metadata (node liveness, store capacity, range descriptors for meta ranges, cluster settings) via a peer-to-peer **gossip** protocol — not for actual row data, only metadata. Every node connects to a handful of peers; info propagates cluster-wide within seconds.

### Commands
```bash
# Node liveness (backed by gossip + KV)
cockroach node status --certs-dir=/var/lib/cockroach/certs --host=localhost

cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT * FROM crdb_internal.gossip_nodes;"

cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT * FROM crdb_internal.gossip_liveness;"
```

---

## 14. Raft Consensus

Within each range, the replicas run an independent **Raft** consensus group. Writes must be acknowledged by a quorum (majority) of replicas before being committed — e.g., with RF=3, 2 of 3 must ack. This is what gives CockroachDB strong consistency and survives node failure (tolerates floor((RF-1)/2) node losses per range).

### Commands
```sql
-- Raft state per range
SELECT range_id, replicas, lease_holder FROM crdb_internal.ranges LIMIT 20;
```
```bash
# Per-range Raft debug endpoint (needs node up, adjust node id/range id)
curl -sk https://localhost:8080/_status/raft --cacert /var/lib/cockroach/certs/ca.crt
```

---

## 15. Metadata Tables (Meta Ranges)

CockroachDB stores range location info itself as KV data, in two special "meta ranges":
- **meta1**: locates meta2 ranges (root of the addressing tree; there's only one meta1 range, cluster-wide)
- **meta2**: locates all actual data ranges

Plus system tables under `system.*` (e.g., `system.namespace`, `system.descriptor`, `system.zones`, `system.jobs`) hold cluster metadata usable via normal SQL.

### Commands
```sql
SHOW TABLES FROM system;

SELECT * FROM system.namespace LIMIT 20;

SELECT * FROM crdb_internal.zones;
```

---

## Quick Health-Check Script for node1 (run today)

```bash
#!/bin/bash
CERTS=/var/lib/cockroach/certs
HOST=localhost

echo "== systemd status =="
sudo systemctl status cockroach --no-pager

echo "== node status =="
cockroach node status --certs-dir=$CERTS --host=$HOST

echo "== cluster id =="
cockroach sql --certs-dir=$CERTS --host=$HOST -e "SELECT crdb_internal.cluster_id();"

echo "== ranges summary =="
cockroach sql --certs-dir=$CERTS --host=$HOST -e "SELECT count(*) AS total_ranges FROM crdb_internal.ranges;"

echo "== store status =="
cockroach sql --certs-dir=$CERTS --host=$HOST -e "SELECT * FROM crdb_internal.kv_store_status;"
```

Save this as `check_node1.sh`, `chmod +x check_node1.sh`, run with `./check_node1.sh`.

---

## After node2 and node3 Join — Cluster Verification Commands

Once you start node2/node3 with `--join=<node1-ip>:26257,<node2-ip>:26257,<node3-ip>:26257` and run `cockroach init` (if not already initialized):

```bash
# Should now show 3 rows (one per node)
cockroach node status --certs-dir=/var/lib/cockroach/certs --host=localhost

# Confirm all nodes see the same cluster ID
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT crdb_internal.cluster_id();"
# run the same on node2 and node3 -> IDs must match

# Confirm replication factor 3 is actually being achieved
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT range_id, replicas FROM crdb_internal.ranges LIMIT 20;"
# 'replicas' array should show 3 distinct node ids per range

# Check replicas are spread across the 3 nodes (not all on node1)
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT unnest(replicas) AS node_id, count(*) FROM crdb_internal.ranges GROUP BY 1 ORDER BY 1;"

# Gossip should show all 3 nodes
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT * FROM crdb_internal.gossip_nodes;"

# Simulate/observe leaseholder distribution across nodes
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT lease_holder, count(*) FROM crdb_internal.ranges GROUP BY 1 ORDER BY 1;"

# Web UI (much easier visual check once cluster is up)
# http://<any-node-ip>:8080  -> Overview, Databases, Metrics, Advanced Debug -> Raft/Ranges
```

### Fault-tolerance sanity test (do this only in a lab, once 3 nodes are up)
```bash
# Stop node2, cluster should stay available (quorum = 2 of 3 still up)
sudo systemctl stop cockroach   # run on node2

# From node1 or node3, confirm reads/writes still work
cockroach sql --certs-dir=/var/lib/cockroach/certs --host=localhost \
  -e "SELECT 1;"

# Bring node2 back
sudo systemctl start cockroach  # run on node2

# Confirm it rejoins and catches up
cockroach node status --certs-dir=/var/lib/cockroach/certs --host=localhost
```

---

## One-Line Cheat Sheet

| Concept | Fast check |
|---|---|
| Node up? | `systemctl status cockroach` |
| Node list | `cockroach node status` |
| Cluster ID match | `SELECT crdb_internal.cluster_id();` on each node |
| Range count | `SELECT count(*) FROM crdb_internal.ranges;` |
| Replica placement | `SELECT range_id, replicas FROM crdb_internal.ranges;` |
| Leaseholder spread | `SELECT lease_holder, count(*) FROM crdb_internal.ranges GROUP BY 1;` |
| Gossip peers | `SELECT * FROM crdb_internal.gossip_nodes;` |
| Store info | `SELECT * FROM crdb_internal.kv_store_status;` |
| Metadata tables | `SHOW TABLES FROM system;` |
