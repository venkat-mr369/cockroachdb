# CockroachDB Internals — Beginner Step-by-Step Labs

**Your cluster:**

| Node | Private IP | User running CockroachDB |
|---|---|---|
| Node1 | 10.10.1.10 | cockroach |
| Node2 | 10.10.2.10 | cockroach |
| Node3 | 10.10.3.10 | cockroach |

**Your data:** database `company`, tables `employees`, `orders`, `customers`, ~1,000,000 rows each.

**Store path on every node:** `/var/lib/cockroach/data`, owned by the `cockroach` user.

Every lab below is written as **individual numbered steps**. Run one, look at the output, then move to the next. Don't skip ahead.

---

## Before You Start: One-Time Setup

**Step 1.** Log into Node1 as the `cockroach` user (you're already doing this).
```bash
whoami
```
Expected output: `cockroach`

**Step 2.** Save the SQL connection command into a variable, so you don't retype it every time.
```bash
export SQL="cockroach sql --insecure --host=10.10.1.10"
```

**Step 3.** Save the live store path into a variable.
```bash
export STORE=/var/lib/cockroach/data
```

**Step 4.** Confirm your tables and row counts still look right.
```bash
$SQL -e "SELECT count(*) FROM company.employees;"
```
Expected output: `1000000`

**Step 5.** Repeat for the other two tables.
```bash
$SQL -e "SELECT count(*) FROM company.orders;"
$SQL -e "SELECT count(*) FROM company.customers;"
```

**Step 6.** Switch into the `company` database so you don't have to prefix every table name.
```bash
$SQL -e "USE company;"
```
(Note: each `$SQL -e "..."` call is a new session, so in practice you'll either keep writing `company.employees` or put multiple statements in one `-e` string. Both are shown below where needed.)

---

# PART 1 — STORAGE ENGINE

## 1. Pebble Storage Engine

**What it is:** Pebble is the actual program that reads and writes data to disk on each node. Think of CockroachDB's SQL layer as the "front desk" and Pebble as the "warehouse" underneath it — every row you ever inserted physically lives in Pebble's files.

**Lab:**

**Step 1.** Look at what's inside your live store folder.
```bash
ls -la $STORE/
```
You'll see files ending in `.sst`, one file called `MANIFEST-XXXXXX`, and one called `CURRENT`.

**Step 2.** Look at what `CURRENT` contains.
```bash
cat $STORE/CURRENT
```
Expected output: one line, the name of the current active MANIFEST file, e.g. `MANIFEST-000123`.

**Step 3.** Ask the running node for live Pebble metrics over HTTP (safe to run anytime, doesn't touch the lock).
```bash
curl -s http://10.10.1.10:8080/_status/vars | grep -i pebble | head -10
```

**Why it matters:** Everything else in this guide (SSTables, LSM trees, MVCC, GC) is really just "what Pebble is doing under the hood." Steps 1–2 are you looking directly at that warehouse.

---

## 2. SSTables (Sorted String Tables)

**What it is:** An SSTable is one single file holding many rows, sorted by key, and — once written — never edited again. New writes go into new SSTables; old data eventually gets cleaned up in the background.

**Lab (this one needs a safe copy first, see the note below):**

**Step 1.** Make a folder you own, to hold a copy of the store.
```bash
mkdir -p /home/cockroach/pebble-snapshot
```

**Step 2.** Save that path into a variable.
```bash
export SNAPSHOT=/home/cockroach/pebble-snapshot
```

**Step 3.** Copy the live store into it. (Live node keeps running — this is just a `cp`, not touching the database itself.)
```bash
cp -r $STORE/* $SNAPSHOT/
```

**Step 4.** Confirm the copy has files in it.
```bash
ls -la $SNAPSHOT/*.sst | head -5
```

**Step 5.** Ask Pebble's own tool to describe one SSTable's properties. Pick any filename from Step 4's output.
```bash
cockroach debug pebble sstable properties $SNAPSHOT/000582.sst
```
Expected output: a block of stats — number of keys, file size, compression info.

**Why it matters:** Every one of your 1,000,000 `employees` rows ended up inside SSTables like this one, spread across many files as they were written in batches.

> **Why we copy first:** `cockroach debug pebble` needs exclusive access to the folder. Your live node already has it open, so pointing the tool directly at `$STORE` gives a lock error. Copying to `$SNAPSHOT` sidesteps that — see the earlier discussion in this conversation for the tradeoffs of doing this on a real production system.

---

## 3. LSM Trees (Log-Structured Merge Trees)

**What it is:** An LSM tree organizes SSTables into numbered "levels" (0 through 6). Level 0 is the newest, smallest, messiest data. Higher levels are older, bigger, and more tidied-up. A background process called **compaction** periodically merges lower levels into higher ones.

**Lab:**

**Step 1.** (If you didn't just do it above) refresh your snapshot so it reflects current data.
```bash
rm -rf $SNAPSHOT/* && cp -r $STORE/* $SNAPSHOT/
```

**Step 2.** Ask Pebble to show you the level breakdown.
```bash
cockroach debug pebble db lsm $SNAPSHOT/
```
Expected output: a small table, one row per level, showing file count and total size per level.

**Step 3.** Check live compaction activity on the running node.
```bash
curl -s http://10.10.1.10:8080/_status/vars | grep -i compaction
```

**Why it matters:** With 3,000,000 total rows loaded across your three tables, you should see real numbers in multiple levels, not just Level 0 — proof that compaction has already run at least once in the background.

---

## 4. MemTables

**What it is:** Before a write ever becomes a file on disk, it sits in memory first, in a structure called a MemTable. Once it fills up, it gets "flushed" to disk as a brand-new Level-0 SSTable.

**Lab:**

**Step 1.** Check current MemTable size before making a big write.
```bash
curl -s http://10.10.1.10:8080/_status/vars | grep -i memtable
```

**Step 2.** Run a large update — this touches roughly 200,000 rows (every 5th employee, department = IT).
```bash
$SQL -e "UPDATE company.employees SET salary = salary + 100 WHERE department = 'IT';"
```

**Step 3.** Check MemTable size again, right after.
```bash
curl -s http://10.10.1.10:8080/_status/vars | grep -i memtable
```

**Why it matters:** Compare Step 1's numbers to Step 3's. A jump (or a flush event) shows you that update briefly filled up memory before Pebble wrote it out to disk as a new SSTable.

---

## 5. WAL (Write-Ahead Log)

**What it is:** Before a write even reaches the MemTable, it's first appended to a log file on disk called the WAL. If the node crashed the instant after your write, CockroachDB replays the WAL on restart to make sure nothing is lost.

**Lab:**

**Step 1.** List the current WAL (`.log`) files.
```bash
ls -la $STORE/*.log
```

**Step 2.** Insert one new row.
```bash
$SQL -e "INSERT INTO company.customers VALUES (2000000, 'Customer2000000', 'Hyderabad');"
```

**Step 3.** List the `.log` files again.
```bash
ls -la $STORE/*.log
```

**Why it matters:** Compare file sizes between Step 1 and Step 3 — the WAL file grew, because your one-row insert was durably recorded there the instant it was written, before it ever touched a MemTable or SSTable.

---

## 6. Write Path (what happens, start to finish, for one write)

**What it is:** The full journey of a single `INSERT` or `UPDATE`, from your SQL client all the way down to disk.

**Lab:**

**Step 1.** Turn tracing on, run one insert, turn tracing off.
```bash
$SQL -e "SET tracing = on; INSERT INTO company.orders (order_id, emp_id, amount, status) VALUES (gen_random_uuid(), 42, 999.99, 'Pending'); SET tracing = off;"
```

**Step 2.** Ask CockroachDB to show you the trace of what just happened.
```bash
$SQL -e "SELECT operation, message FROM [SHOW TRACE FOR SESSION] LIMIT 30;"
```

**Why it matters:** Reading through that trace output, you'll see the sequence: parse the SQL → figure out which range owns this new row → send it to that range's leaseholder → get agreement from a majority of replicas (Raft) → commit → confirm back to you. That's the entire write path for one real row in your `orders` table.

---

## 7. Read Path (what happens, start to finish, for one read)

**What it is:** The journey of a `SELECT`, from your SQL client to wherever the data actually lives.

**Lab:**

**Step 1.** Trace a fast, indexed read (by primary key).
```bash
$SQL -e "SET tracing = on; SELECT * FROM company.employees WHERE emp_id = 500000; SET tracing = off;"
$SQL -e "SELECT operation, message FROM [SHOW TRACE FOR SESSION] LIMIT 30;"
```

**Step 2.** Compare against a slow, unindexed read (by department, no index exists on this column).
```bash
$SQL -e "EXPLAIN ANALYZE SELECT * FROM company.employees WHERE department = 'HR';"
```

**Why it matters:** Step 1 goes straight to one range, one round trip — fast. Step 2's `EXPLAIN ANALYZE` output will show it scanning across many ranges, because there's no index on `department` to narrow the search. This is exactly why indexes matter.

---

# PART 2 — MVCC (Multi-Version Concurrency Control)

## 8. MVCC Architecture

**What it is:** CockroachDB never overwrites a row in place. Every `UPDATE` writes a brand-new version of that row, tagged with the timestamp it was written at. Old versions stick around for a while rather than being destroyed immediately.

**Lab:**

**Step 1.** Look at one employee's current salary and its internal timestamp.
```bash
$SQL -e "SELECT emp_id, salary, crdb_internal_mvcc_timestamp FROM company.employees WHERE emp_id = 1;"
```

**Step 2.** Update that same employee.
```bash
$SQL -e "UPDATE company.employees SET salary = 99999 WHERE emp_id = 1;"
```

**Step 3.** Look at the row again.
```bash
$SQL -e "SELECT emp_id, salary, crdb_internal_mvcc_timestamp FROM company.employees WHERE emp_id = 1;"
```

**Why it matters:** The timestamp in Step 3 is newer than Step 1's. The old salary value isn't gone — it's a second, older version of the same row, physically sitting right next to the new one in Pebble.

---

## 9. Version Storage

**What it is:** Every one of those old row versions has to physically live somewhere until it's cleaned up. This step shows you how long CockroachDB is configured to keep them around.

**Lab:**

**Step 1.** Check the retention setting for `employees`.
```bash
$SQL -e "SHOW ZONE CONFIGURATION FOR TABLE company.employees;"
```
Look for a line containing `gc.ttlseconds` in the output.

**Step 2.** Use time travel to read the *old* salary from Step 8, before you'd normally expect it to be cleaned up.
```bash
$SQL -e "SELECT emp_id, salary FROM company.employees AS OF SYSTEM TIME '-2m' WHERE emp_id = 1;"
```

**Why it matters:** That old salary value is still readable because it hasn't aged past the `gc.ttlseconds` window yet. This is what "version storage" actually costs you on disk — every update you ran keeps its old self around for that whole window.

---

## 10. Garbage Collection (GC)

**What it is:** A background process that permanently deletes old row versions once they've aged past the retention window from Lab 9.

**Lab:**

**Step 1.** Make a fresh copy of your store so you can inspect it (same as Lab 2 — copy, don't touch live).
```bash
rm -rf $SNAPSHOT/* && cp -r $STORE/* $SNAPSHOT/
```

**Step 2.** Ask for per-range storage stats, which include how much data is old vs. "live."
```bash
$SQL -e "SELECT range_id, span_stats FROM [SHOW RANGES FROM TABLE company.employees WITH DETAILS] LIMIT 3;"
```

**Why it matters:** Look at the `span_stats` JSON in the output — it tells you the byte-level breakdown of a range, including how much of it is old/GC-able versions versus live data. Your Lab 4 bulk update (200,000 rows) directly inflated this number for `employees`.

---

## 11. Closed Timestamps

**What it is:** A promise CockroachDB makes, per range: "no more writes will land below this exact timestamp." This lets *any* replica — not just the leaseholder — safely answer certain reads on its own, without asking the leaseholder first.

**Lab:**

**Step 1.** Check the cluster-wide setting that controls how far behind "now" the closed timestamp trails.
```bash
$SQL -e "SHOW CLUSTER SETTING kv.closed_timestamp.target_duration;"
```

**Step 2.** Run a "follower read" against `customers` — a read that's allowed to be served by any replica.
```bash
$SQL -e "SELECT count(*) FROM company.customers AS OF SYSTEM TIME follower_read_timestamp() WHERE city = 'Hyderabad';"
```

**Why it matters:** That query didn't have to specifically go to the leaseholder — any of the 3 replicas holding a copy of that range could answer it, because the closed timestamp guarantees no surprise write is still in flight below that point in time.

---

# PART 3 — RANGE MANAGEMENT

## 12. Range Splits

**What it is:** A "range" is one contiguous chunk of your table's data (default target ~512MB). When a range gets too big, CockroachDB automatically splits it into two smaller ranges. You can also force a split manually.

**Lab:**

**Step 1.** See how many ranges `employees` currently has.
```bash
$SQL -e "SELECT count(*) FROM [SHOW RANGES FROM TABLE company.employees];"
```

**Step 2.** Force a manual split at a specific employee ID.
```bash
$SQL -e "ALTER TABLE company.employees SPLIT AT VALUES (500000);"
```

**Step 3.** Count the ranges again.
```bash
$SQL -e "SELECT count(*) FROM [SHOW RANGES FROM TABLE company.employees];"
```

**Why it matters:** The count in Step 3 should be one higher than Step 1 — you just watched a range get cut into two, live, with zero downtime.

---

## 13. Range Merges

**What it is:** The opposite of a split — if two neighboring ranges are both small enough, CockroachDB (or you, manually) can merge them back into one.

**Lab:**

**Step 1.** Undo the manual split from Lab 12.
```bash
$SQL -e "ALTER TABLE company.employees UNSPLIT AT VALUES (500000);"
```

**Step 2.** Count ranges again.
```bash
$SQL -e "SELECT count(*) FROM [SHOW RANGES FROM TABLE company.employees];"
```

**Why it matters:** This should drop back down by one, close to what you saw in Lab 12 Step 1 — proof merges are just as live and non-disruptive as splits.

---

## 14. Lease Transfers

**What it is:** Every range has one "leaseholder" — the replica currently responsible for serving reads/writes for it. A lease transfer moves that responsibility to a different node, without moving any actual data.

**Lab:**

**Step 1.** Find a range in `orders` and see which node currently holds its lease.
```bash
$SQL -e "SELECT range_id, start_key, lease_holder FROM [SHOW RANGES FROM TABLE company.orders] LIMIT 3;"
```

**Step 2.** Note one `range_id` from the output, then move its lease to node 2.
```bash
$SQL -e "ALTER RANGE RELOCATE LEASE TO 2 FOR (SELECT start_key FROM [SHOW RANGES FROM TABLE company.orders] LIMIT 1);"
```

**Step 3.** Check the lease holder again.
```bash
$SQL -e "SELECT range_id, start_key, lease_holder FROM [SHOW RANGES FROM TABLE company.orders] LIMIT 3;"
```

**Why it matters:** The `lease_holder` value for that range should now show `2` — you just moved read/write authority to Node2 without moving a single byte of the underlying data.

> Note: `ALTER RANGE RELOCATE` syntax varies a bit by version. If Step 2 errors, run `ALTER RANGE RELOCATE ??` to see the exact syntax for your installed CockroachDB version.

---

## 15. Automatic Rebalancing

**What it is:** CockroachDB constantly checks whether ranges/leases are evenly spread across your 3 nodes, and quietly moves them around in the background if one node has too many.

**Lab:**

**Step 1.** Check range and lease counts per node right now.
```bash
$SQL -e "SELECT node_id, range_count, lease_count FROM crdb_internal.kv_store_status;"
```

**Step 2.** Wait a few minutes (rebalancing runs on its own schedule), then run the same query again.
```bash
$SQL -e "SELECT node_id, range_count, lease_count FROM crdb_internal.kv_store_status;"
```

**Why it matters:** If Step 1 showed uneven numbers (e.g., after your Lab 12/14 manual changes), Step 2 should look more balanced — no human intervened, the cluster fixed itself.

---

## 16. Automatic Sharding

**What it is:** There's no separate "sharding" command in CockroachDB — Lab 12's range splits *are* the sharding mechanism. As your table grows, it keeps splitting itself into more ranges automatically.

**Lab:**

**Step 1.** Check how many ranges each of your 3 tables currently has.
```bash
$SQL -e "SELECT table_name, count(*) AS num_ranges FROM [SHOW CLUSTER RANGES WITH TABLES] WHERE table_name IN ('employees','orders','customers') GROUP BY table_name;"
```

**Why it matters:** You never ran a single "shard this table" command for any of these — every range you see here was created automatically the moment each table's data crossed the per-range size threshold during your 1,000,000-row loads.

---

# PART 4 — REPLICATION INTERNALS

## 17. Replica Factor

**What it is:** How many copies of each range exist across your cluster. With 3 nodes, the standard (and max useful) setting is 3 replicas — one copy per node.

**Lab:**

**Step 1.** Check the current replica factor for `employees`.
```bash
$SQL -e "SHOW ZONE CONFIGURATION FOR TABLE company.employees;"
```
Look for `num_replicas = 3` in the output.

**Why it matters:** With exactly 3 nodes, you can't usefully set this higher than 3 — there'd be nowhere to put a 4th copy. This also caps how many node failures you can survive (see Lab 18).

---

## 18. Quorum

**What it is:** A write only counts as "committed" once a **majority** of replicas agree to it. With 3 replicas, that means 2 out of 3.

**Lab (conceptual — no command needed yet, just understand the math before Lab 21):**

**Step 1.** Confirm your replica count once more (this is what quorum math is based on).
```bash
$SQL -e "SELECT range_id, replicas FROM [SHOW RANGES FROM TABLE company.employees] LIMIT 3;"
```
You should see something like `replicas: {1,2,3}` — 3 replicas per range.

**Why it matters:** With 3 replicas, losing 1 node still leaves 2 — a majority — so writes keep working. Losing 2 nodes leaves only 1, which is not a majority, and writes would stop. You'll actually test this in Lab 21.

---

## 19. Leader Election (Raft)

**What it is:** Within each range's group of 3 replicas, one is elected the "Raft leader" — the only one allowed to accept new writes into the replication log. If it goes down, the other two vote for a new one.

**Lab:**

**Step 1.** Check live Raft metrics on the node.
```bash
curl -s http://10.10.1.10:8080/_status/vars | grep -i raft | head -10
```

**Why it matters:** Right now, every one of your table's ranges has exactly one Raft leader among its 3 replicas. You'll watch this change live in Lab 21 when we simulate a node failure.

---

## 20. Leaseholder Election

**What it is:** Separate from the Raft leader, one replica also holds the "lease" — the right to serve reads directly and coordinate writes for that range. Normally this is the same node as the Raft leader, but not always.

**Lab:**

**Step 1.** Check current leaseholders for a few `orders` ranges — write this down, you'll compare it after Lab 21.
```bash
$SQL -e "SELECT range_id, lease_holder FROM [SHOW RANGES FROM TABLE company.orders] LIMIT 10;"
```

**Why it matters:** This is your "before" snapshot. In Lab 21, when we kill a node, you'll see which of these leaseholders had to move.

---

## 21. Failover

**What it is:** What actually happens when a node goes down — do your queries still work?

**Lab:**

**Step 1.** Take a "before" snapshot of leaseholders for `orders`.
```bash
$SQL -e "SELECT lease_holder, count(*) FROM [SHOW RANGES FROM TABLE company.orders] GROUP BY lease_holder;"
```

**Step 2.** On Node3, stop the CockroachDB process.
```bash
# Run this ON Node3, logged in as the cockroach user
cockroach quit --insecure --host=10.10.3.10
```

**Step 3.** Back on Node1, immediately try a query against `orders`.
```bash
$SQL -e "SELECT count(*) FROM company.orders;"
```
Expected output: still `1000000` — it should work despite Node3 being down.

**Step 4.** Check leaseholders again.
```bash
$SQL -e "SELECT lease_holder, count(*) FROM [SHOW RANGES FROM TABLE company.orders] GROUP BY lease_holder;"
```

**Step 5.** Check overall node status.
```bash
cockroach node status --insecure --host=10.10.1.10
```

**Why it matters:** Step 3 still worked because every range still had 2 of its 3 replicas alive — a majority (quorum, from Lab 18). Any range that had its leaseholder on Node3 shows a new leaseholder in Step 4 — Node1 or Node2 took over automatically. Nothing was lost, and you (mostly) didn't notice.

---

## 22. Replica Recovery

**What it is:** What happens when the failed node comes back — how does it catch back up?

**Lab:**

**Step 1.** On Node3, start CockroachDB again.
```bash
# Run this ON Node3, logged in as the cockroach user
cockroach start --insecure --store=/var/lib/cockroach/data \
  --listen-addr=0.0.0.0:26257 --advertise-addr=10.10.3.10:26257 \
  --http-addr=0.0.0.0:8080 \
  --join=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257 \
  --log-dir=/var/lib/cockroach/logs
```

**Step 2.** Back on Node1, check that all 3 nodes are live again.
```bash
cockroach node status --insecure --host=10.10.1.10
```

**Step 3.** Confirm `orders` ranges show Node3 back in their replica list.
```bash
$SQL -e "SELECT range_id, replicas FROM [SHOW RANGES FROM TABLE company.orders] LIMIT 5;"
```

**Why it matters:** Node3 rejoined missing whatever writes happened while it was down. The other two nodes automatically shipped it the missing data (or a full snapshot, if it was down too long), and it silently caught back up — no manual repair needed.

---

## Quick Reference — All Commands In One Place

| Topic | Key Command |
|---|---|
| See store files | `ls -la $STORE/` |
| Copy store safely | `cp -r $STORE/* $SNAPSHOT/` |
| LSM levels | `cockroach debug pebble db lsm $SNAPSHOT/` |
| Ranges for a table | `SELECT * FROM [SHOW RANGES FROM TABLE company.x]` |
| Ranges across tables | `SELECT * FROM [SHOW CLUSTER RANGES WITH TABLES]` |
| Zone / replica factor | `SHOW ZONE CONFIGURATION FOR TABLE company.x` |
| Force a split | `ALTER TABLE company.x SPLIT AT VALUES (...)` |
| Force a merge | `ALTER TABLE company.x UNSPLIT AT VALUES (...)` |
| Move a lease | `ALTER RANGE RELOCATE LEASE TO <node> FOR (...)` |
| Node status | `cockroach node status --insecure --host=10.10.1.10` |
| Trace a query | `SET tracing = on; ...; SHOW TRACE FOR SESSION` |

**One habit to keep for all of this:** never point `cockroach debug pebble` at `$STORE` directly while the node is running — always copy to `$SNAPSHOT` first, as covered earlier in this conversation.
