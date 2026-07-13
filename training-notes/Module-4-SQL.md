CockroachDB lab that works in a **single-node `--insecure` cluster**.

Start CockroachDB:

```bash
cockroach start-single-node \
--insecure \
--listen-addr=localhost \
--http-addr=localhost:8080 \
--background
```

Connect:

```bash
cockroach sql --insecure
```

---

### 1. Databases

#### Create Database

```sql
CREATE DATABASE training;
```

Verify

```sql
SHOW DATABASES;
```

Switch database

```sql
USE training;
```

Show current database

```sql
SELECT current_database();
```

Rename database

```sql
ALTER DATABASE training RENAME TO trainingdb;
```

Use renamed database

```sql
USE trainingdb;
```

Drop database

```sql
DROP DATABASE trainingdb CASCADE;
```

Create again

```sql
CREATE DATABASE trainingdb;
USE trainingdb;
```

---

### Demo

Imagine one CockroachDB cluster hosting multiple applications.

```
Cluster
|
|-- HR Database
|-- Sales Database
|-- Finance Database
```

Each database is isolated.

---

# 2. Schemas

Create schemas

```sql
CREATE SCHEMA hr;
CREATE SCHEMA sales;
CREATE SCHEMA finance;
```

List schemas

```sql
SHOW SCHEMAS;
```

---

### Demo

```
trainingdb

|
|-- hr
|-- sales
|-- finance
```

Schemas organize objects.

---

# 3. Tables

Create Employee table

```sql
CREATE TABLE hr.employees
(
    emp_id INT PRIMARY KEY,
    emp_name STRING,
    salary DECIMAL,
    dept STRING
);
```

Create Department table

```sql
CREATE TABLE hr.departments
(
    dept_id INT PRIMARY KEY,
    dept_name STRING
);
```

Show tables

```sql
SHOW TABLES;
```

Describe table

```sql
SHOW COLUMNS FROM hr.employees;
```

---

Insert data

```sql
INSERT INTO hr.employees VALUES
(1,'John',50000,'IT'),
(2,'David',60000,'HR'),
(3,'Sara',70000,'Finance');
```

View data

```sql
SELECT * FROM hr.employees;
```

---

# 4. Data Types

Create datatype demo

```sql
CREATE TABLE datatype_demo
(
id INT,

name STRING,

salary DECIMAL(10,2),

joining_date DATE,

login_time TIME,

created TIMESTAMP,

active BOOL,

remarks STRING,

binary_data BYTES,

uuid_col UUID DEFAULT gen_random_uuid()
);
```

Insert

```sql
INSERT INTO datatype_demo
(id,name,salary,joining_date,login_time,created,active,remarks,binary_data)

VALUES

(
1,
'Venkat',
55000.50,
CURRENT_DATE,
CURRENT_TIME,
CURRENT_TIMESTAMP,
true,
'DBA',
b'ABC'
);
```

Query

```sql
SELECT * FROM datatype_demo;
```

---

# 5. Constraints

Create table

```sql
CREATE TABLE constraint_demo
(
id INT PRIMARY KEY,

name STRING NOT NULL,

salary DECIMAL CHECK (salary>0),

email STRING UNIQUE
);
```

Valid insert

```sql
INSERT INTO constraint_demo
VALUES
(1,'John',50000,'john@gmail.com');
```

Try duplicate email

```sql
INSERT INTO constraint_demo
VALUES
(2,'David',70000,'john@gmail.com');
```

Expected

```
duplicate key
```

Try negative salary

```sql
INSERT INTO constraint_demo
VALUES
(3,'Sara',-100,'sara@gmail.com');
```

Expected

```
check constraint failed
```

---

# 6. Primary Keys

Primary key uniquely identifies every row.

```sql
CREATE TABLE customers
(
customer_id INT PRIMARY KEY,

customer_name STRING
);
```

Insert

```sql
INSERT INTO customers VALUES
(1,'Alice');
```

Duplicate

```sql
INSERT INTO customers VALUES
(1,'Bob');
```

Fails.

Show indexes

```sql
SHOW INDEXES FROM customers;
```

Observe

```
primary
```

---

Demo

```
1 Alice

2 Bob

3 David
```

No duplicates.

---

# 7. Secondary Indexes

Create

```sql
CREATE TABLE products
(
product_id INT PRIMARY KEY,

product_name STRING,

price DECIMAL,

category STRING
);
```

Insert

```sql
INSERT INTO products VALUES
(1,'Laptop',60000,'Electronics'),
(2,'TV',45000,'Electronics'),
(3,'Mouse',800,'Accessories'),
(4,'Keyboard',1500,'Accessories');
```

Without index

```sql
EXPLAIN
SELECT *
FROM products
WHERE category='Accessories';
```

Create index

```sql
CREATE INDEX idx_category
ON products(category);
```

Again

```sql
EXPLAIN
SELECT *
FROM products
WHERE category='Accessories';
```

Observe

```
Index Scan
```

instead of table scan.

---

# 8. Unique Index

```sql
CREATE TABLE users
(
id INT PRIMARY KEY,

username STRING
);
```

Create unique index

```sql
CREATE UNIQUE INDEX idx_username
ON users(username);
```

Insert

```sql
INSERT INTO users VALUES
(1,'venkat');
```

Duplicate

```sql
INSERT INTO users VALUES
(2,'venkat');
```

Fails.

---

# 9. Computed Columns

```sql
CREATE TABLE orders
(
order_id INT PRIMARY KEY,

price DECIMAL,

quantity INT,

total DECIMAL AS (price*quantity) STORED
);
```

Insert

```sql
INSERT INTO orders
(order_id,price,quantity)

VALUES
(1,100,5);
```

Query

```sql
SELECT * FROM orders;
```

Output

```
100 × 5

total=500
```

Update

```sql
UPDATE orders
SET quantity=10
WHERE order_id=1;
```

Observe

```
total

1000
```

Automatically calculated.

---

# 10. Sequences

Create

```sql
CREATE SEQUENCE emp_seq;
```

Next value

```sql
SELECT nextval('emp_seq');
```

Again

```sql
SELECT nextval('emp_seq');
```

Output

```
1

2

3

4
```

Use in table

```sql
CREATE TABLE emp_sequence
(
id INT DEFAULT nextval('emp_seq'),

name STRING
);
```

Insert

```sql
INSERT INTO emp_sequence(name)
VALUES
('John'),
('David'),
('Sara');
```

Query

```sql
SELECT * FROM emp_sequence;
```

---

# 11. Views

Create

```sql
CREATE VIEW high_salary AS

SELECT *

FROM hr.employees

WHERE salary>55000;
```

Query

```sql
SELECT *
FROM high_salary;
```

Update base table

```sql
UPDATE hr.employees

SET salary=90000

WHERE emp_id=1;
```

View again

```sql
SELECT *
FROM high_salary;
```

Automatically reflects changes.

---

# 12. Transactions

Begin

```sql
BEGIN;
```

Transfer salary

```sql
UPDATE hr.employees

SET salary=salary-1000

WHERE emp_id=1;
```

```sql
UPDATE hr.employees

SET salary=salary+1000

WHERE emp_id=2;
```

Commit

```sql
COMMIT;
```

Rollback demo

```sql
BEGIN;
```

```sql
UPDATE hr.employees

SET salary=0;
```

Oops...

```sql
ROLLBACK;
```

Verify

```sql
SELECT * FROM hr.employees;
```

Data restored.

---

# 13. ACID Properties Demo

Create account table

```sql
CREATE TABLE accounts
(
id INT PRIMARY KEY,

balance INT
);
```

Insert

```sql
INSERT INTO accounts VALUES

(1,10000),

(2,5000);
```

Transaction

```sql
BEGIN;
```

Debit

```sql
UPDATE accounts

SET balance=balance-1000

WHERE id=1;
```

Credit

```sql
UPDATE accounts

SET balance=balance+1000

WHERE id=2;
```

Commit

```sql
COMMIT;
```

Explain:

* Atomicity → Both updates succeed or both roll back.
* Consistency → Data remains valid.
* Isolation → Concurrent transactions don't interfere.
* Durability → After `COMMIT`, data survives node restarts.

---

# 14. UPSERT

Create table

```sql
CREATE TABLE inventory
(
id INT PRIMARY KEY,

item STRING,

qty INT
);
```

Insert

```sql
UPSERT INTO inventory

VALUES
(1,'Laptop',10);
```

Run again

```sql
UPSERT INTO inventory

VALUES
(1,'Laptop',20);
```

Query

```sql
SELECT *
FROM inventory;
```

Observe

```
20
```

Existing row updated automatically.

---

# 15. IMPORT

Create CSV

```
1,John,50000
2,David,60000
3,Sara,70000
```

Table

```sql
CREATE TABLE employee_import
(
id INT,

name STRING,

salary INT
);
```

Import

```sql
IMPORT INTO employee_import
CSV DATA
('nodelocal://1/employees.csv');
```

Verify

```sql
SELECT *
FROM employee_import;
```

---

# 16. EXPORT

Export to CSV

```sql
EXPORT INTO CSV

'nodelocal://1/export'

FROM

SELECT *

FROM employee_import;
```

Files are written to the node-local storage directory configured for the node.

---

### Suggested Lab Flow for Students

1. Create Database
2. Create Schemas
3. Create Tables
4. Insert 1 million rows (using `generate_series()`)
5. Explore Data Types
6. Test Constraints
7. Observe Primary Key behavior
8. Compare queries before/after creating Secondary Indexes with `EXPLAIN`
9. Test Unique Index violations
10. Use Computed Columns
11. Generate IDs with Sequences
12. Create and query Views
13. Perform `BEGIN`, `COMMIT`, and `ROLLBACK`
14. Demonstrate ACID with a money transfer example
15. Demonstrate `UPSERT`
16. Import CSV data
17. Export query results to CSV

