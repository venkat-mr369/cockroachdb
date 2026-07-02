## **Module 3 – Storage Layer (Hands-on Lab)**

here its contains only **practical notes**, **queries**, and **verification commands**.

---

### Storage Layer – Lab

### Objective

Understand how CockroachDB stores data internally and verify storage behavior using SQL and operating system commands.

---

### Lab 1 – Create Sample Database

```sql
CREATE DATABASE ams;

USE ams;

CREATE TABLE employee
(
    emp_id INT PRIMARY KEY,
    emp_name STRING,
    salary INT
);
```

Verify

```sql
SHOW DATABASES;

SHOW TABLES;

SHOW CREATE TABLE employee;
```

---

### Lab 2 – Load Data

Insert 1 Million rows

```sql
INSERT INTO employee
SELECT
id,
'Employee-'||id,
(random()*100000)::INT
FROM generate_series(1,1000000) id;
```

Verify

```sql
SELECT COUNT(*) FROM employee;
```

Expected

```text
1000000
```

---

### Lab 3 – Insert More Data

```sql
INSERT INTO employee
SELECT
id,
'Employee-'||id,
(random()*100000)::INT
FROM generate_series(1000001,2000000) id;
```

Verify

```sql
SELECT COUNT(*) FROM employee;
```

Expected

```text
2000000
```

---

### Lab 4 – Explain Plan

```sql
EXPLAIN SELECT * FROM employee WHERE emp_id=1500000;
```

Explain

* Index Lookup
* KV Read
* Execution Plan

---

### Lab 5 – DistSQL

```sql
EXPLAIN (DISTSQL)

SELECT * FROM employee;
```

---

### Lab 6 – Show Ranges

```sql
SHOW RANGES FROM TABLE employee;
```

Observe

* Range ID
* Start Key
* End Key
* Leaseholder
* Replicas

---

### Lab 7 – Runtime Information

```sql
SELECT * FROM crdb_internal.node_runtime_info;
```

Useful columns

* Node ID
* Build Version
* Started Time

---

### Lab 8 – Store Information

```sql
SELECT * FROM crdb_internal.kv_store_status;
```

Observe

* Store ID
* Capacity
* Used Space
* Available Space

---

### Lab 9 – Database Size

Linux

```bash
du -sh /var/lib/cockroach/data
```

Detailed

```bash
du -sh /var/lib/cockroach/data/*
```

---

### Lab 10 – Cockroach Process

```bash
ps -ef | grep cockroach
```

---

### Lab 11 – Open Files

```bash
lsof -p $(pidof cockroach)
```

Useful for explaining that Pebble keeps multiple SSTable files open.

---

### Lab 12 – Disk Usage

```bash
df -h
```

Storage directory

```bash
ls -lh /var/lib/cockroach/data
```

---

### Lab 13 – Monitor Storage Growth

```bash
watch -n 2 "du -sh /var/lib/cockroach/data"
```

Students can watch storage grow during inserts.

---

### Lab 14 – CPU Utilization

```bash
top
```

or

```bash
htop
```

---

### Lab 15 – Disk I/O

```bash
iostat -x 2
```

Explain

* Read IOPS
* Write IOPS
* Utilization

---

### Lab 16 – Current Sessions

```sql
SHOW SESSIONS;
```

---

### Lab 17 – Current Queries

```sql
SHOW CLUSTER QUERIES;
```

While loading data

students can see the running INSERT.

---

### Lab 18 – Jobs

```sql
SHOW JOBS;
```

Explain

Background jobs

* Backup
* Restore
* Import
* Changefeed

---

### Lab 19 – Cluster Settings

```sql
SHOW CLUSTER SETTINGS;
```

Specific setting

```sql
SHOW CLUSTER SETTING version;
```

Persisted values

```sql
SELECT *
FROM system.settings;
```

Explain

* Built-in defaults
* Overridden settings

---

### Lab 20 – Session Variables

```sql
SHOW ALL;
```

Example

```sql
SHOW sql_safe_updates;
```

Disable

```sql
SET sql_safe_updates=false;
```

Reconnect

```sql
SHOW sql_safe_updates;
```

Students observe that it returns to **ON**, demonstrating that it is a session-level setting.

---

### Lab 21 – Storage Monitoring Commands

```bash
systemctl status cockroach

ss -tlnp | grep cockroach

free -h

vmstat 2

iostat -x 2

df -h

du -sh /var/lib/cockroach/data

ps -ef | grep cockroach
```

---

### DBA Interview Questions

### Q1

Where does CockroachDB store data?

**Answer**

Pebble Storage Engine.

---

### Q2

Which engine does CockroachDB use?

**Answer**

Pebble (LSM Tree).

---

### Q3

Where is WAL stored?

**Answer**

Inside the Pebble store under the configured `--store` directory (for example, `/var/lib/cockroach/data`). WAL files are managed internally by Pebble rather than exposed like PostgreSQL's `pg_wal`.

---

### Q4

How do you monitor storage?

```bash
du -sh /var/lib/cockroach/data
```

---

### Q5

How do you view storage information?

```sql
SELECT * FROM crdb_internal.kv_store_status;
```

---

### Q6

Where are Cluster Settings stored?

```sql
SELECT * FROM system.settings;
```

Only overridden settings are persisted; default values are built into the CockroachDB binary.

---

