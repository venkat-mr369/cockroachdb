# CockroachDB Internals Deep-Dive — Using Your employees / orders / customers Dataset

Cluster:

| Node | Private IP |
|---|---|
| Node1 | 10.10.1.10 |
| Node2 | 10.10.2.10 |
| Node3 | 10.10.3.10 |

```bash
export NODE1=10.10.1.10
export NODE2=10.10.2.10
export NODE3=10.10.3.10
export SQL="cockroach sql --insecure --host=$NODE1"
```

Assumes you've already run your `CREATE TABLE` + 1M-row `INSERT` + `count(*)` steps (Lab 4). Everything below builds on that data, so run counts once more to confirm state before starting:

```bash
$SQL -e "SELECT count(*) FROM employees; SELECT count(*) FROM orders; SELECT count(*) FROM customers;"
```

---

## 1. Storage Engine — Pebble

With 1M rows in `employees` (~100+ bytes/row) you've pushed several MB of real data through the engine — enough to see actual LSM behavior instead of an empty demo table.

```bash
# On the node hosting store data (adjust path to your --store flag)
ls -la /var/lib/cockroach/data/
cat /var/lib/cockroach/data/CURRENT
```

```bash
curl -s http://$NODE1:8080/_status/vars | grep -i pebble | head -30
```

**Explanation:** Every row you inserted into `employees`, `orders`, and `customers` physically landed as key-value pairs in Pebble on whichever node held the leaseholder for that particular range at insert time. `CURRENT` names the active MANIFEST — Pebble's ledger of which SSTables exist and at what LSM level.

---

## 2. SSTables

```bash
cockroach debug pebble db lsm /var/lib/cockroach/data/
```

Look specifically for growth after your 1M-row loads — Level 0 should show multiple files from the bulk `INSERT ... SELECT ... generate_series` batches.

**Explanation:** Each `generate_series(1,1000000)` insert streamed enough data to trigger several MemTable flushes, each becoming a new immutable Level-0 SSTable — sorted by the `employees` primary key (`emp_id`), `orders` primary key (`order_id` UUID), etc. Because `order_id` is a random UUID, those SSTables' key ranges are much more randomly distributed than `employees`' sequential `emp_id` — worth comparing directly:

```bash
$SQL -e "SELECT range_id, start_key, end_key FROM [SHOW RANGES FROM TABLE employees] ORDER BY start_key LIMIT 5;"
$SQL -e "SELECT range_id, start_key, end_key FROM [SHOW RANGES FROM TABLE orders] ORDER BY start_key LIMIT 5;"
```

You'll see `employees` ranges split on clean numeric boundaries (sequential `emp_id`), while `orders` ranges split on scattered UUID prefixes — a good live illustration of why UUID primary keys spread writes more evenly (avoiding hot ranges) but hurt range-locality for scans.

---

## 3. LSM Trees

```bash
cockroach debug pebble db lsm /var/lib/cockroach/data/
```

**Explanation:** After bulk-loading 3M rows total across 3 tables, expect compactions to have already run in the background, merging Level-0 files into Level 1/2. Confirm with:

```bash
curl -s http://$NODE1:8080/_status/vars | grep -i compaction
```

Compactions reclaim space from any overwritten rows and keep read amplification (number of files to check per read) bounded even as your dataset grows.

---

## 4. MemTables

Trigger visible MemTable flush activity live:

```bash
$SQL -e "UPDATE employees SET salary = salary + 100 WHERE department = 'IT';"
curl -s http://$NODE1:8080/_status/vars | grep -i memtable
```

**Explanation:** That single `UPDATE` touches ~200,000 rows (1M/5 departments). Each row's new MVCC version gets written to the WAL then the active MemTable, likely forcing at least one flush given the row count — you should see `memtable` size metrics fluctuate right after running it.

---

## 5. WAL

```bash
ls -la /var/lib/cockroach/data/*.log
```

Run a write and immediately check WAL growth:

```bash
$SQL -e "INSERT INTO customers VALUES (2000000, 'Customer2000000', 'Hyderabad');"
ls -la /var/lib/cockroach/data/*.log
```

**Explanation:** That single-row insert is durable the instant it's fsynced to the WAL — well before it ever becomes part of a MemTable flush or SSTable. If the node crashed right now, replaying this WAL segment on restart recovers that row.

---

## 6. Write Path (traced on real data)

```bash
$SQL -e "SET tracing = on; INSERT INTO orders (order_id, emp_id, amount, status) VALUES (gen_random_uuid(), 42, 999.99, 'Pending'); SET tracing = off; SELECT operation, message FROM [SHOW TRACE FOR SESSION] LIMIT 40;"
```

**Explanation:** Read through the trace output and you'll see: SQL parses the `INSERT` → resolves the `orders` table descriptor → computes the target range for the new UUID key → routes to that range's leaseholder → proposes to Raft → quorum ack → commit → response. This is the full write path, visible end-to-end for one of your actual rows.

---

## 7. Read Path

```bash
$SQL -e "SET tracing = on; SELECT * FROM employees WHERE emp_id = 500000; SET tracing = off; SELECT operation, message FROM [SHOW TRACE FOR SESSION] LIMIT 40;"
```

Compare a point lookup (above, uses the primary key index directly) against a full scan:

```bash
$SQL -e "EXPLAIN ANALYZE SELECT * FROM employees WHERE department = 'HR';"
```

**Explanation:** The point lookup on `emp_id` (primary key) goes straight to one range's leaseholder — one round trip. The `department` filter has no index, so `EXPLAIN ANALYZE` will show a full scan across *all* employee ranges (you have 1M rows split across many ranges) — a good live demonstration of why you'd add `CREATE INDEX ON employees(department);` for this query pattern.

---

## 8. MVCC

```bash
$SQL -e "SELECT emp_id, salary, crdb_internal_mvcc_timestamp FROM employees WHERE emp_id = 1;"
$SQL -e "UPDATE employees SET salary = 99999 WHERE emp_id = 1;"
$SQL -e "SELECT emp_id, salary, crdb_internal_mvcc_timestamp FROM employees WHERE emp_id = 1;"
```

**Explanation:** The second timestamp is strictly greater — the old `salary` value for `emp_id=1` isn't gone, it's a prior MVCC version of the same logical key, still on disk until GC'd. Prove it with time travel:

```bash
$SQL -e "SELECT emp_id, salary FROM employees AS OF SYSTEM TIME '-30s' WHERE emp_id = 1;"
```

That returns the pre-update salary, read straight from an older MVCC version, no undo log involved.

---

## 9. MVCC Architecture

```bash
$SQL -e "SELECT emp_id, salary, crdb_internal_mvcc_timestamp FROM employees WHERE emp_id BETWEEN 1 AND 5 ORDER BY emp_id, crdb_internal_mvcc_timestamp DESC;"
```

**Explanation:** Physically, `emp_id=1`'s two versions are two separate Pebble keys: `/employees/1@t2` and `/employees/1@t1`, stored adjacent in sorted order (newest first). There's no separate version-store structure — the LSM tree itself holds the full version history inline.

---

## 10. Version Storage

```bash
$SQL -e "SHOW ZONE CONFIGURATION FOR TABLE employees;"
```

Check `gc.ttlseconds` in the output — this governs how long your `emp_id=1` salary history above stays queryable via `AS OF SYSTEM TIME`.

**Explanation:** With 1M rows and a bulk `UPDATE` touching 200K of them earlier, you've now materially grown the MVCC version count for `employees`. That extra history is bounded by this TTL (default ~25h) — after which GC reclaims it.

---

## 11. Garbage Collection

```bash
$SQL -e "SELECT range_id, span_stats FROM [SHOW RANGES FROM TABLE employees WITH DETAILS] LIMIT 5;"
```

**Explanation:** Your bulk UPDATE on the IT department created ~200,000 obsolete row versions. The `span_stats` JSON column (only populated `WITH DETAILS`, since it's expensive to compute) includes byte/key counts for that range, including how much is "live" vs. old/GC-able. The GC queue will, once versions age past `gc.ttlseconds`, mark them for deletion; the next compaction physically removes those bytes. Until then, both old and new salary values coexist on disk — this is the storage cost of MVCC you're paying for that update.

---

## 12. Closed Timestamps

```bash
$SQL -e "SELECT range_id, replicas, lease_holder FROM [SHOW RANGES FROM TABLE customers] LIMIT 5;"
$SQL -e "SHOW CLUSTER SETTING kv.closed_timestamp.target_duration;"
```

Test a follower read against `customers` (all rows currently `'Hyderabad'`):

```bash
$SQL -e "SELECT count(*) FROM customers AS OF SYSTEM TIME follower_read_timestamp() WHERE city = 'Hyderabad';"
```

**Explanation:** This query can be served by *any* replica of the `customers` ranges — not just the leaseholder — because the read timestamp is guaranteed ≤ the closed timestamp. On a geo-distributed cluster this avoids a network hop to a potentially distant leaseholder.

---

## 13. Range Management

```bash
$SQL -e "SELECT table_name, count(*) AS num_ranges FROM [SHOW CLUSTER RANGES WITH TABLES] WHERE table_name IN ('employees','orders','customers') GROUP BY table_name;"
```

**Explanation:** With 1M rows each, `employees`, `orders`, and `customers` are each split across dozens of ranges already (default target ~512MB per range, though row width determines exact count). This query shows you exactly how many ranges your own data produced.

---

## 14. Range Splits

Force an explicit split partway through the `employees` keyspace:

```bash
$SQL -e "ALTER TABLE employees SPLIT AT VALUES (500000);"
$SQL -e "SELECT range_id, start_key, end_key FROM [SHOW RANGES FROM TABLE employees] WHERE start_key LIKE '%499%' OR start_key LIKE '%500%';"
```

**Explanation:** This manually forces a boundary at `emp_id=500000`, splitting whatever range currently holds that key into two independent ranges, each with its own Raft group and leaseholder from that point forward — useful right before a big scan or migration touching only half the table.

---

## 15. Range Merges

```bash
$SQL -e "ALTER TABLE employees UNSPLIT AT VALUES (500000);"
```

**Explanation:** Undoes the forced split above — if both resulting ranges are small enough to be under the merge threshold, CockroachDB's merge queue will recombine them back into one Raft group, given your table is now back to default split policy.

---

## 16. Lease Transfers

```bash
$SQL -e "SELECT range_id, start_key, lease_holder FROM [SHOW RANGES FROM TABLE orders] LIMIT 5;"
```

Note a `range_id`/`start_key` and its current `lease_holder` node, then relocate the lease to Node2 explicitly:

```bash
$SQL -e "ALTER RANGE RELOCATE LEASE TO 2 FOR (SELECT start_key FROM [SHOW RANGES FROM TABLE orders] LIMIT 1);"
```
*(`ALTER RANGE ... RELOCATE` syntax has changed across versions — run `ALTER RANGE RELOCATE ??` or check the docs for your installed release to confirm)*

**Explanation:** This moves read/write-serving authority for that `orders` range to Node2 without moving any of the underlying SSTable data — only the lease. Useful if most of your query traffic against recent `orders` rows is actually originating near Node2.

---

## 17. Automatic Rebalancing

```bash
$SQL -e "SELECT node_id, range_count, lease_count FROM crdb_internal.kv_store_status;"
```

**Explanation:** After bulk-loading 3M rows, ranges initially land wherever the leaseholder happened to be when each batch was written. Over the following minutes, the allocator compares `range_count`/`lease_count` across your 3 nodes and moves replicas/leases from any node ended up disproportionately loaded — re-run this query a few minutes after the load and compare the distribution.

---

## 18. Automatic Sharding

```bash
$SQL -e "SELECT table_name, count(*) FROM [SHOW CLUSTER RANGES WITH TABLES] WHERE table_name IN ('employees','orders','customers') GROUP BY table_name;"
```

**Explanation:** You never issued a single "shard" command — every one of these ranges was created automatically as your `generate_series(1,1000000)` inserts pushed each table's total size past the per-range split threshold. This *is* automatic sharding: driven entirely by data volume, not manual configuration.

---

## 19. Replication Internals

```bash
$SQL -e "SELECT range_id, replicas FROM [SHOW RANGES FROM TABLE employees] LIMIT 5;"
```

**Explanation:** Each row returned shows a `replicas` array like `{1,2,3}` — one independent Raft group per range, replicated across Node1/Node2/Node3. `employees` alone likely has 30–50+ of these independent Raft groups running concurrently.

---

## 20. Replica Factor

```bash
$SQL -e "SHOW ZONE CONFIGURATION FOR TABLE employees;"
```

Confirm `num_replicas = 3` (default, matching your 3-node cluster). Try (harmlessly) setting it explicitly:

```bash
$SQL -e "ALTER TABLE employees CONFIGURE ZONE USING num_replicas = 3;"
```

**Explanation:** With exactly 3 nodes, `num_replicas=3` is the max useful value — you can't ask for 5 replicas across only 3 physical nodes. This also means you can only tolerate **1** node failure and stay available.

---

## 21. Quorum

**Explanation (conceptual, ties directly to your cluster):** Every write to `employees`, `orders`, or `customers` needs 2 of your 3 nodes to acknowledge before committing. Kill any one node and every range still has a majority (2 of 3) among the survivors — kill two and every range loses quorum and becomes unavailable for writes. This is exactly what §24 below will demonstrate.

---

## 22. Leader Election (Raft)

```bash
curl -s http://$NODE1:8080/_status/vars | grep -i raft
```

**Explanation:** For each of the ~100+ ranges spread across your 3 tables, one specific node is currently the Raft leader accepting log entries. When you kill a node in §24, watch how many of that node's leader-ships get re-elected among the remaining two.

---

## 23. Leaseholder Election

```bash
$SQL -e "SELECT range_id, lease_holder FROM [SHOW RANGES FROM TABLE orders] LIMIT 10;"
```

**Explanation:** Note which node IDs currently hold leases for `orders` ranges. This is your baseline — compare it against the same query after the failover test below.

---

## 24. Failover

```bash
# Snapshot leaseholder distribution before
$SQL -e "SELECT lease_holder, count(*) FROM [SHOW RANGES FROM TABLE orders] GROUP BY lease_holder;"

# Kill Node3
ssh $NODE3 "cockroach quit --insecure --host=$NODE3"
# or on Node3 directly: pkill -f 'cockroach start'

# Immediately re-run a query against orders — it should still succeed
$SQL -e "SELECT count(*) FROM orders;"

# Watch leases move off the dead node
$SQL -e "SELECT lease_holder, count(*) FROM [SHOW RANGES FROM TABLE orders] GROUP BY lease_holder;"

cockroach node status --insecure --host=$NODE1
```

**Explanation:** `SELECT count(*) FROM orders` still returns 1000000 even with Node3 down, because every range still has 2 of 3 replicas alive — quorum intact. Any range whose leaseholder *was* Node3 fails over: the survivors elect a new Raft leader and a new lease is granted to Node1 or Node2. The only visible cost is a brief latency blip on ranges that had to re-elect, nothing is lost or unavailable.

---

## 25. Replica Recovery

```bash
# Bring Node3 back
ssh $NODE3 "cockroach start --insecure --store=path=/var/lib/cockroach/data --listen-addr=$NODE3:26257 --join=$NODE1:26257,$NODE2:26257,$NODE3:26257 --background"

# Watch it rejoin and catch up
cockroach node status --insecure --host=$NODE1 --all

# Confirm replicas re-include node 3 again
$SQL -e "SELECT range_id, replicas FROM [SHOW RANGES FROM TABLE orders] LIMIT 5;"
```

**Explanation:** Node3 rejoins with stale Raft logs for every range it hosts replicas of (`employees`, `orders`, `customers` — likely all of them, given RF=3 across only 3 nodes). The Raft leader for each range ships the missing log entries (or a full snapshot if too far behind) to catch Node3 back up. Once caught up, the allocator may rebalance some leases back onto Node3 to restore even load across all three of your nodes.

---

## Bonus: One Query That Ties It All Together

```bash
$SQL -e "
SELECT
  table_name,
  count(*) AS num_ranges,
  count(DISTINCT lease_holder) AS distinct_leaseholders
FROM [SHOW CLUSTER RANGES WITH TABLES]
WHERE table_name IN ('employees','orders','customers')
GROUP BY table_name;
"
```

This single query shows, per table: how many ranges your 1M-row load produced (§13, §18), and how spread out leaseholder duty is across your 3 nodes (§16, §17, §23) — the entire replication/sharding story for your dataset in one shot.

---

**Version note:** This guide uses `SHOW RANGES FROM TABLE ...` and `SHOW CLUSTER RANGES WITH TABLES` because your cluster's version has removed `table_name`/`start_pretty`/`end_pretty` from `crdb_internal.ranges` directly (the error you hit — CockroachDB's own hint pointed at `SHOW [CLUSTER] RANGES WITH TABLES`). If you're on an older version where those columns still exist on `crdb_internal.ranges`, both forms work; on newer versions, `SHOW RANGES` is the supported path going forward. Run `SHOW RANGES FROM TABLE employees;` once by itself first to see exactly which columns your version returns before running the fuller queries above. `ALTER RANGE RELOCATE` syntax has also shifted across releases — run `ALTER RANGE RELOCATE ??` on your version to confirm before using it live.
