After configuring the localities and restarting all 6 nodes, 

* **REGIONAL BY TABLE**: All rows of a table are stored primarily in the specified region (Mumbai or Singapore).
* **REGIONAL BY ROW**: Rows are automatically placed based on the `crdb_internal_region` column, allowing different rows of the same table to reside in different regions.
* **GLOBAL**: The table is replicated across regions to provide low-latency reads from any region, making it suitable for relatively static reference or lookup data.

you can run the following SQL labs
Connect to SQL:

```bash
cockroach sql --insecure --host=10.10.1.10:26257
```

---

### Step 1: Create a Multi-Region Database

```sql
CREATE DATABASE sales;
```

Set the primary region:

```sql
ALTER DATABASE sales PRIMARY REGION "mumbai";
```

Add the secondary region:

```sql
ALTER DATABASE sales ADD REGION "singapore";
```

Verify:

```sql
SHOW REGIONS FROM DATABASE sales;
```

Expected:

```text
mumbai
singapore
```

Use the database:

```sql
USE sales;
```

---

## Lab 1 – REGIONAL BY TABLE

Create the table:

```sql
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name STRING,
    city STRING
);
```

Place the table in the Mumbai region:

```sql
ALTER TABLE customers
SET LOCALITY REGIONAL BY TABLE
IN PRIMARY REGION;
```

Verify:

```sql
SHOW CREATE TABLE customers;
```

---

Create another table in Singapore:

```sql
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    amount DECIMAL
);
```

Move it to Singapore:

```sql
ALTER TABLE orders
SET LOCALITY REGIONAL BY TABLE
IN "singapore";
```

Verify:

```sql
SHOW CREATE TABLE orders;
```

---

Insert data:

```sql
INSERT INTO customers VALUES
(1,'Rahul','Mumbai'),
(2,'Anjali','Pune');
```

```sql
INSERT INTO orders VALUES
(101,1,1200),
(102,2,2500);
```

---

## Lab 2 – REGIONAL BY ROW

Create the table:

```sql
CREATE TABLE employees (
    emp_id INT PRIMARY KEY,
    emp_name STRING,
    region crdb_internal_region NOT NULL,
    city STRING
) LOCALITY REGIONAL BY ROW;
```

Verify:

```sql
SHOW CREATE TABLE employees;
```

Insert Mumbai employees:

```sql
INSERT INTO employees VALUES
(1,'Venkat','mumbai','Mumbai'),
(2,'Raj','mumbai','Pune');
```

Insert Singapore employees:

```sql
INSERT INTO employees VALUES
(3,'David','singapore','Singapore'),
(4,'John','singapore','Jurong');
```

Verify:

```sql
SELECT * FROM employees;
```

Observe ranges:

```sql
SHOW RANGES FROM TABLE employees;
```

---

## Lab 3 – GLOBAL Table

Create a lookup table:

```sql
CREATE TABLE countries (
    country_code STRING PRIMARY KEY,
    country_name STRING
);
```

Convert it to GLOBAL:

```sql
ALTER TABLE countries
SET LOCALITY GLOBAL;
```

Insert data:

```sql
INSERT INTO countries VALUES
('IN','India'),
('SG','Singapore'),
('US','United States');
```

Verify:

```sql
SHOW CREATE TABLE countries;
```

Query:

```sql
SELECT * FROM countries;
```

---

## Verify Localities

```sql
SELECT node_id, locality
FROM crdb_internal.kv_node_status
ORDER BY node_id;
```

---

## Verify Database Regions

```sql
SHOW REGIONS FROM DATABASE sales;
```

---

## Verify Survival Goal

```sql
SHOW SURVIVAL GOAL FROM DATABASE sales;
```

---

## Show Zone Configuration

```sql
SHOW ZONE CONFIGURATION FROM DATABASE sales;
```

---

## Show Table Partitions

```sql
SHOW RANGES FROM TABLE customers;

SHOW RANGES FROM TABLE orders;

SHOW RANGES FROM TABLE employees;

SHOW RANGES FROM TABLE countries;
```



