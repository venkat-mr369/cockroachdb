
Load testing production-like growth is:

* Create a `customers` table.
* Write a SQL script that inserts **1,000 rows**.
* Schedule it with **cron** to run every **10 minutes**.


Swithing Ubuntu User to Cockroch user  `cockroach` user (`/var/lib/cockroach`), 

keep everything there.
```
ubuntu@crdb-node1:~$ pwd
/home/ubuntu
ubuntu@crdb-node1:~$ sudo su - cockroach
cockroach@crdb-node1:~$ pwd
/var/lib/cockroach
cockroach@crdb-node1:~$ ls -lrt
total 16
drwxr-xr-x 6 cockroach cockroach 12288 Jul 23 22:59 logs
drwxr-xr-x 5 cockroach cockroach  4096 Jul 24 00:12 data
```

---

## Step 1: Create the Database

```bash
cockroach sql --insecure
```

```sql
CREATE DATABASE labdb;

USE labdb;
```

---

## Step 2: Create the Customers Table

```sql
CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_name STRING NOT NULL,
    city STRING,
    created_at TIMESTAMP DEFAULT now()
);
```

Verify:

```sql
SHOW TABLES;
```

---

## Step 3: Create an Insert Script

Exit SQL.

```sql
\q
```

Create the file:

```bash
cd /var/lib/cockroach

vi insert_customers.sql
```

Paste:

```sql
INSERT INTO labdb.customers (customer_name, city)
SELECT
    'Customer-' || g,
    CASE (g % 10)
        WHEN 0 THEN 'Hyderabad'
        WHEN 1 THEN 'Bangalore'
        WHEN 2 THEN 'Chennai'
        WHEN 3 THEN 'Mumbai'
        WHEN 4 THEN 'Delhi'
        WHEN 5 THEN 'Pune'
        WHEN 6 THEN 'Kolkata'
        WHEN 7 THEN 'Jaipur'
        WHEN 8 THEN 'Ahmedabad'
        ELSE 'Visakhapatnam'
    END
FROM generate_series(1,1000) AS g;
```

Save.

---

## Step 4: Test the Script

```bash
cockroach sql \
  --insecure \
  --file=/var/lib/cockroach/insert_customers.sql
```

Verify:

```bash
cockroach sql --insecure
```

```sql
SELECT count(*) FROM labdb.customers;
```

Expected:

```text
 count
-------
1000
```

Run it again:

```bash
cockroach sql \
  --insecure \
  --file=/var/lib/cockroach/insert_customers.sql
```

Now:

```sql
SELECT count(*) FROM labdb.customers;
```

```text
2000
```

Each execution inserts another 1,000 rows.

---

## Step 5: Create a Shell Script

```bash
vi /var/lib/cockroach/load_customers.sh
```

Contents:

```bash
#!/bin/bash

/usr/local/bin/cockroach sql \
  --insecure \
  --file=/var/lib/cockroach/insert_customers.sql
```

Make it executable:

```bash
chmod +x /var/lib/cockroach/load_customers.sh
```

Test:

```bash
/var/lib/cockroach/load_customers.sh
```

---

## Step 6: Schedule Every 10 Minutes

Edit the crontab for the `cockroach` user:

```bash
crontab -e
```

Add:

```cron
*/10 * * * * /var/lib/cockroach/load_customers.sh >> /var/lib/cockroach/logs/customer_load.log 2>&1
```

Save and exit.

---

## Step 7: Verify the Cron Job

List scheduled jobs:

```bash
crontab -l
```

Expected:

```cron
*/10 * * * * /var/lib/cockroach/load_customers.sh >> /var/lib/cockroach/logs/customer_load.log 2>&1
```

---

## Step 8: Monitor the Log

```bash
tail -f /var/lib/cockroach/logs/customer_load.log
```

Every 10 minutes you'll see the execution logged.

---

## Step 9: Verify Data Growth

```bash
cockroach sql --insecure
```

```sql
SELECT count(*) FROM labdb.customers;
```

Example:

| Time             |  Rows |
| ---------------- | ----: |
| Initial          |     0 |
| After first run  | 1,000 |
| After 10 minutes | 2,000 |
| After 20 minutes | 3,000 |
| After 30 minutes | 4,000 |

---

### Directory Layout

```text
/var/lib/cockroach
├── data/
├── logs/
│   └── customer_load.log
├── insert_customers.sql
└── load_customers.sh
```

### Why this approach?

For a DBA lab, this closely mirrors how recurring maintenance or load-generation jobs are often implemented:

* SQL logic is kept in a reusable `.sql` file.
* A shell script invokes the CockroachDB CLI.
* `cron` provides the scheduler.
* Output is redirected to a log file for monitoring and troubleshooting.

This makes it easy to modify the insert volume (for example, 5,000 or 10,000 rows) by changing only the `generate_series()` range in the SQL script.
