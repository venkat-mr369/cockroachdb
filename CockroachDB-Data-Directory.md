---

### CockroachDB Data Directory (`/var/lib/cockroach/data`)

### Storage Engine Files (Pebble — like RocksDB/LSM Tree)

| File | What It Does | PostgreSQL Equivalent | Cassandra Equivalent |
|------|-------------|----------------------|---------------------|
| `000004.log`, `000005.log`, `000014.log` | **WAL (Write-Ahead Log)** — every write goes here FIRST before saving to disk. If server crashes, data recovers from here | `pg_wal/` folder (WAL files) | `commitlog/` folder |
| `000006.log`, `000007.log` | Older WAL files not yet cleaned up | Same | Same |
| `000011.log` | Active WAL file (58MB — currently being written to) | Current WAL segment | Current commitlog |
| `000016.sst` | **SST file (Sorted String Table)** — actual data stored on disk in sorted order. This is where your tables/rows live | Data files in `base/` folder (like `16384`, `16385`) | `*-Data.db` SSTable files |
| `MANIFEST-000001` | **Manifest** — tracks which SST files exist and their key ranges. Like a "table of contents" for all data files | `pg_control` + `pg_class` catalog | `manifest.json` in each table folder |
| `OPTIONS-000003` | Storage engine configuration options | `postgresql.conf` | `cassandra.yaml` |
| `LOCK` | Prevents two CockroachDB processes from using same data folder at once | `postmaster.pid` | `cassandra.pid` |

### CockroachDB Specific Files

| File | What It Does |
|------|-------------|
| `cockroach.listen-addr` | Stores the listen address (10.0.1.220:26257) |
| `cockroach.sql-addr` | Stores the SQL address |
| `cockroach.http-addr` | Stores the Web UI address (10.0.1.220:8080) |
| `cockroach.advertise-addr` | Address this node tells other nodes to reach it |
| `cockroach.advertise-sql-addr` | SQL address advertised to other nodes |
| `STORAGE_MIN_VERSION` | Minimum storage format version supported |
| `REMOTE-OBJ-CATALOG-000001` | Tracks remote objects (for cloud storage) |
| `temp-dirs-record.txt` | Tracks temporary directories created |

### Folders

| Folder | What It Does |
|--------|-------------|
| `logs/` | CockroachDB application logs (not WAL). Like `postgresql.log` or `system.log` in Cassandra |
| `auxiliary/` | Internal metadata |
| `cockroach-temp1714307815` | Temporary files for sorting/joins (like `pgsql_tmp` in PostgreSQL) |

---

## How Data Flows — Simple Example

Imagine you run:
```sql
INSERT INTO accounts VALUES (1, 1000.50);
```

Here's what happens step by step:

```
Step 1: Write hits WAL first (000011.log)
         ↓
         "Hey I'm writing id=1, balance=1000.50"
         This is FAST — just append to file
         ↓
Step 2: Data sits in MEMORY (memtable)
         ↓
         Fast reads come from here
         ↓
Step 3: When memory is full → FLUSH to SST file (000016.sst)
         ↓
         Data sorted by key, written to disk
         ↓
Step 4: MANIFEST updated
         ↓
         "000016.sst has keys from 'a' to 'z'"
         ↓
Step 5: Old WAL cleaned up (000004.log, 000005.log deleted eventually)
```

---

## Visual Comparison

```
PostgreSQL                CockroachDB              Cassandra
─────────                ─────────────             ─────────
pg_wal/                  000011.log (WAL)          commitlog/
  ↓                        ↓                        ↓
shared_buffers           memtable (RAM)            memtable (RAM)
  ↓                        ↓                        ↓
base/16384               000016.sst                *-Data.db
(heap files)             (SST files)               (SSTable files)
  ↓                        ↓                        ↓
pg_control               MANIFEST-000001           manifest.json
─────────                ─────────────             ─────────

Storage Model:           Storage Model:            Storage Model:
B-Tree                   LSM Tree                  LSM Tree
(update in place)        (append + compact)        (append + compact)
```

---

## Key Difference Explained Simply

**PostgreSQL (B-Tree):** Like editing a notebook — you erase old text and write new text in same place. Fast reads, slower writes.

**CockroachDB & Cassandra (LSM Tree):** Like writing on sticky notes and stacking them. New writes just add new sticky notes on top. Periodically you "compact" — merge all sticky notes into one clean page. Fast writes, reads need to check multiple levels.

That's why you see multiple `.sst` files — as data grows, more SST files are created, and CockroachDB periodically **compacts** (merges) them to keep reads fast.

---

## Check It Live

```bash
# See SST file details
cd /var/lib/cockroach/data
ls -lh *.sst

# See WAL files
ls -lh *.log

# See application logs
ls -lh logs/

# Check active log
tail -50 logs/cockroach.log
```
