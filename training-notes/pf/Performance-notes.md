I can provide information based on the available knowledge sources, but I must be transparent: **the knowledge sources provided only cover a subset of these topics in depth**. I'll cover what's available and flag where information is limited.

---

# CockroachDB Performance — In-Depth Guide

---

## 1. Transaction Performance

- Use **multi-row statements** instead of multiple single-row statements for `INSERT`, `UPSERT`, and `DELETE` — a single multi-row statement is significantly faster. [[SQL Best Practices](https://www.cockroachlabs.com/docs/stable/performance-best-practices-overview.html)]
- Use `SELECT FOR UPDATE` to **preemptively lock rows** and reduce the likelihood of retry errors. [[Optimize Distributed SQL](https://www.cockroachlabs.com/blog/oreilly-tips-distributed-sql-database/)]
- **Reduce transaction time** and avoid hot rows to limit contention.
- Use **built-in retry logic** in your language's client libraries where available.
- Do **not** include bulk `INSERT` statements within an explicit transaction.
- If you get error code `40001` with message `transaction deadline exceeded`, break up the query into **smaller batches**. [[SQL Best Practices](https://www.cockroachlabs.com/docs/stable/performance-best-practices-overview.html)]

---

## 2. UPSERT Performance

- On tables **without secondary indexes**: use `UPSERT` instead of `INSERT ON CONFLICT DO UPDATE`.
  - `INSERT ON CONFLICT` always performs a **read before write**.
  - `UPSERT` **writes without reading**, making it faster. [[SQL Best Practices](https://www.cockroachlabs.com/docs/stable/performance-best-practices-overview.html)]

```sql
-- Faster (no secondary indexes)
UPSERT INTO users (id, name) VALUES (1, 'Alice');

-- Slower alternative
INSERT INTO users (id, name) VALUES (1, 'Alice')
  ON CONFLICT (id) DO UPDATE SET name = 'Alice';
```

- On tables **with secondary indexes**: there is **no performance difference** between `UPSERT` and `INSERT ON CONFLICT`.
- `INSERT` without `ON CONFLICT` may not scan for existing values — this can be **faster than UPSERT** in some cases. [[SQL Best Practices](https://www.cockroachlabs.com/docs/stable/performance-best-practices-overview.html)]

---

## 3. IMPORT Performance

- Use `IMPORT INTO` to bulk-insert **CSV data** into an existing table — it performs better than `INSERT` for large datasets. [[SQL Best Practices](https://www.cockroachlabs.com/docs/stable/performance-best-practices-overview.html)]

```sql
IMPORT INTO users (id, name)
CSV DATA ('gs://my-bucket/users.csv');
```

- For **new tables**, `IMPORT` performs better than `INSERT`.
- Experimentally determine the **optimal batch size** (10, 100, 1000 rows) for your workload.

---

## 4. Index Tuning

- The **best index** for a table access has all `WHERE` clause predicates as part of the key, and any additional `SELECT` list columns in the `STORING` clause. [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]

```sql
-- Good: covers WHERE and stores SELECT columns
CREATE INDEX rides_address_times_ix
  ON rides(city, start_address, end_address)
  STORING (start_time, end_time);
```

- Use **partial indexes** to index only filtered data. [[Optimize Distributed SQL](https://www.cockroachlabs.com/blog/oreilly-tips-distributed-sql-database/)]
- Use **composite indexes** for multi-column filtering and sorting.
- Use **hash-sharded indexes** for high-write workloads on monotonically increasing columns to reduce hotspots.
- **Monitor and prune** redundant or unused indexes regularly — indexes add write overhead.
- An `index join` in your query plan means the index is navigating back to the base table to fetch additional columns — consider adding a `STORING` clause to avoid this. [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]

---

## 5. Query Optimization & Cost-Based Optimizer (CBO)

- CockroachDB uses a **Cost-Based Optimizer (CBO)** that determines the best execution plan based on **table statistics** and available **access paths (indexes)**. [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]
- You can help the optimizer by:
  - Keeping **statistics up-to-date**
  - Ensuring the **best set of indexes** exist
  - Using **index hints** when necessary (sparingly — hints may prevent the optimizer from evolving better plans in the future)
- Improvements in SQL performance usually come from:
  1. **Changing or adding indexes**
  2. **SQL rewrites** or using **hints** to force specific execution paths [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]

---

## 6. Statistics

CockroachDB automatically collects table statistics to help the optimizer. Key cluster settings: [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]

| Setting | Description |
|---|---|
| `sql.stats.automatic_collection.enabled` | Enables automatic stats collection |
| `sql.stats.automatic_collection.fraction_stale_rows` | Fraction of stale rows to trigger refresh |
| `sql.stats.automatic_collection.min_stale_rows` | Minimum stale rows to trigger refresh |
| `sql.stats.histogram_collection.enabled` | Enables histogram collection |
| `sql.stats.multi_column_collection.enabled` | Enables multi-column stats |

**Manually collecting statistics:**

```sql
-- Collect stats for entire table
CREATE STATISTICS manualStats FROM rides;

-- Collect stats for specific columns
CREATE STATISTICS city_addresses
  ON city, end_address
  FROM movr.public.rides;
```

- Automatic stats trigger on average when **20% of a table has changed**.
- Watch out for **timestamp columns** (always increasing) and **status columns** — their histograms can become stale quickly and mislead the optimizer. [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]

---

## 7. EXPLAIN & Query Plans

`EXPLAIN` reveals exactly how the optimizer decided to execute a SQL statement. [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]

```sql
-- Basic EXPLAIN
EXPLAIN SELECT city, id
FROM vehicles
WHERE city = 'amsterdam';
```

**Example output interpretation:**

```
• scan
  estimated row count: 1 (<0.01% of the table)
  table: rides@rides_address_ix
  spans: [/'amsterdam'/...]
```

- `scan` — reading from an index or table
- `index join` — fetching extra columns from base table
- `lookup join` — joining via index lookup
- `filter` — applying a filter after scan (not ideal — means index doesn't cover all predicates)
- `sort` — sorting results (expensive if large row count)

---

## 8. EXPLAIN ANALYZE

`EXPLAIN ANALYZE` **actually runs the query** and reports what happened — unlike `EXPLAIN` which only shows what the optimizer *thinks* will happen. [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]

```sql
EXPLAIN ANALYZE SELECT * FROM vehicles v
WHERE v.ext @> '{"brand":"Fuji"}'
AND v.city = 'paris'
AND v.status = 'in_use';
```

**Example output:**
```
planning time: 568μs
execution time: 9ms
distribution: local
vectorized: true
rows read from KV: 2,240 (348 KiB)
cumulative time spent in KV: 6ms
maximum memory usage: 380 KiB
network usage: 0 B (0 messages)
regions: gcp-australia-southeast1
```

- Use `EXPLAIN ANALYZE (DISTSQL)` to get **detailed distributed plans**. [[Optimize Distributed SQL](https://www.cockroachlabs.com/blog/oreilly-tips-distributed-sql-database/)]
- Identify expensive operations like **full scans** or **disk-based sorts**.

---

## 9. Finding Slow Queries

Several methods to identify slow queries: [[Definitive Guide](https://www.cockroachlabs.com/guides/thank-you/?pdf=/pdf/the-definitive-guide-to-cockroachdb-oreilly.pdf)]

1. **DB Console Statements Page** — lists SQL statements with execution statistics; sort by average or cumulative execution time.
2. **`SHOW STATEMENTS`** — shows currently running statements; useful for catching long-running queries.
3. **Slow Query Log** — set the cluster variable:

```sql
SET CLUSTER SETTING sql.log.slow_query.latency_threshold = '500ms';
```

This causes queries exceeding the threshold to emit records to a slow query log.

---

## 10. Bulk Delete Best Practices

| Scenario | Recommendation |
|---|---|
| Delete **all rows** | Use `TRUNCATE` (drops & recreates table — much faster than `DELETE`) |
| Delete **large number of rows** | Use iterative **batch deletes** |
| Delete **expired data** | Use **Row-Level TTL** |

```sql
-- Fastest way to clear a table
TRUNCATE my_table;

-- Row-Level TTL for expired data
ALTER TABLE events SET (
  ttl_expiration_expression = '(created_at + INTERVAL ''30 days'')'
);
```
[[SQL Best Practices](https://www.cockroachlabs.com/docs/stable/performance-best-practices-overview.html)]

---

## ⚠️ Topics Not Covered in Knowledge Sources

The following topics from your list are **not covered in the available knowledge sources** — I cannot provide accurate details without risking making up information:

- MVCC Performance
- ACID Performance Considerations
- EXPORT Performance
- Vectorized Execution (beyond the `vectorized: true` flag in EXPLAIN output)
- Session Settings
- Statement Diagnostics
- SQL Activity Monitoring
- Hotspots & Hot Ranges
- Contention Analysis
- Leaseholder Imbalance
- High CPU / Memory / Latency troubleshooting
- SQL Connection Performance Issues

For these topics, I recommend consulting the official CockroachDB documentation at [cockroachlabs.com/docs](https://www.cockroachlabs.com/docs/stable/) directly.
