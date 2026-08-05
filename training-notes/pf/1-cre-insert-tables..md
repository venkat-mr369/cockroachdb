```sql
CREATE DATABASE perf_lab;

USE perf_lab;
```

---

### Step 2: Create Customers Table

```sql
CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name STRING NOT NULL,
    last_name STRING NOT NULL,
    email STRING UNIQUE,
    phone STRING,
    city STRING,
    state STRING,
    created_at TIMESTAMP DEFAULT now()
);
```

---

### Step 3: Create Products Table

```sql
CREATE TABLE products (
    product_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_name STRING NOT NULL,
    category STRING,
    price DECIMAL(10,2),
    stock_qty INT,
    created_at TIMESTAMP DEFAULT now()
);
```

---

### Step 4: Create Orders Table

```sql
CREATE TABLE orders (
    order_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(customer_id),
    product_id UUID NOT NULL REFERENCES products(product_id),
    quantity INT,
    total_amount DECIMAL(10,2),
    order_status STRING,
    order_date TIMESTAMP DEFAULT now()
);
```

---

### Step 5: Create Payments Table

```sql
CREATE TABLE payments (
    payment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES orders(order_id),
    payment_method STRING,
    payment_status STRING,
    amount DECIMAL(10,2),
    payment_date TIMESTAMP DEFAULT now()
);
```

---

## Insert 100,000 Customers

```sql
INSERT INTO customers
(first_name,last_name,email,phone,city,state)
SELECT
    'First_' || g,
    'Last_' || g,
    'user' || g || '@gmail.com',
    '900000' || lpad((g % 10000)::STRING,4,'0'),
    CASE
        WHEN g % 5 = 0 THEN 'Hyderabad'
        WHEN g % 5 = 1 THEN 'Bangalore'
        WHEN g % 5 = 2 THEN 'Chennai'
        WHEN g % 5 = 3 THEN 'Mumbai'
        ELSE 'Pune'
    END,
    CASE
        WHEN g % 5 = 0 THEN 'Telangana'
        WHEN g % 5 = 1 THEN 'Karnataka'
        WHEN g % 5 = 2 THEN 'Tamil Nadu'
        WHEN g % 5 = 3 THEN 'Maharashtra'
        ELSE 'Maharashtra'
    END
FROM generate_series(1,100000) AS g;
```

---

## Insert 1,000 Products

```sql
INSERT INTO products
(product_name,category,price,stock_qty)
SELECT
    'Product_' || g,
    CASE
        WHEN g % 4 = 0 THEN 'Electronics'
        WHEN g % 4 = 1 THEN 'Books'
        WHEN g % 4 = 2 THEN 'Clothing'
        ELSE 'Home'
    END,
    round((random()*5000+100)::numeric,2),
    (random()*1000)::INT
FROM generate_series(1,1000) AS g;
```

---

## Insert 500,000 Orders

```sql
INSERT INTO orders
(customer_id,product_id,quantity,total_amount,order_status)
SELECT
    (SELECT customer_id FROM customers ORDER BY random() LIMIT 1),
    (SELECT product_id FROM products ORDER BY random() LIMIT 1),
    (random()*5+1)::INT,
    round((random()*10000+100)::numeric,2),
    CASE
        WHEN random()<0.70 THEN 'Completed'
        WHEN random()<0.90 THEN 'Pending'
        ELSE 'Cancelled'
    END
FROM generate_series(1,500000);
```

---

## Insert Payments

```sql
INSERT INTO payments
(order_id,payment_method,payment_status,amount)
SELECT
    order_id,
    CASE
        WHEN random()<0.25 THEN 'UPI'
        WHEN random()<0.50 THEN 'Credit Card'
        WHEN random()<0.75 THEN 'Debit Card'
        ELSE 'Net Banking'
    END,
    CASE
        WHEN random()<0.90 THEN 'Success'
        ELSE 'Failed'
    END,
    total_amount
FROM orders;
```

---

## Verify Row Counts

```sql
SELECT COUNT(*) FROM customers;

SELECT COUNT(*) FROM products;

SELECT COUNT(*) FROM orders;

SELECT COUNT(*) FROM payments;
```

### Expected Output

| Table     |    Rows |
| --------- | ------: |
| customers | 100,000 |
| products  |   1,000 |
| orders    | 500,000 |
| payments  | 500,000 |

---

### These tables are enough for all 27 labs

| Topic                   | Tables Used               |
| ----------------------- | ------------------------- |
| Transaction Performance | customers, orders         |
| MVCC Performance        | customers                 |
| ACID                    | orders, payments          |
| UPSERT                  | products                  |
| IMPORT                  | customers                 |
| EXPORT                  | orders                    |
| Index Tuning            | all tables                |
| Query Optimization      | all tables                |
| Query Optimizer         | orders, customers         |
| Statistics              | all tables                |
| Query Plans             | all tables                |
| EXPLAIN                 | all tables                |
| EXPLAIN ANALYZE         | all tables                |
| Vectorized Execution    | orders                    |
| Session Settings        | all tables                |
| Statement Diagnostics   | all tables                |
| SQL Activity            | all tables                |
| Hotspots                | orders                    |
| Hot Ranges              | orders                    |
| Contention Analysis     | customers, orders         |
| Leaseholder Imbalance   | all tables                |
| Slow Queries            | orders                    |
| High CPU                | large joins on all tables |
| High Memory             | aggregations on orders    |
| High Latency            | distributed joins         |
| SQL Connection Issues   | entire database           |

