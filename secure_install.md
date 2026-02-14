Amazon Linux 2023 across your 3 separate EC2 nodes.

---

## Step 1: Install CockroachDB (run on ALL 3 nodes)

```bash
sudo dnf install -y curl tar
curl https://binaries.cockroachdb.com/cockroach-v24.1.1.linux-amd64.tgz | tar xvz
sudo cp cockroach-v24.1.1.linux-amd64/cockroach /usr/local/bin/
cockroach version
```

---

## Step 2: Create directories (run on ALL 3 nodes)

```bash
sudo mkdir -p /var/lib/cockroach
sudo chown $(whoami) /var/lib/cockroach
cd /var/lib/cockroach
mkdir certs my-safe-directory
chmod 700 certs my-safe-directory
```

---

## Step 3: Create Certificates (run on db1 — 10.0.1.220 ONLY)

```bash
cd /var/lib/cockroach

cockroach cert create-ca --certs-dir=certs --ca-key=my-safe-directory/ca.key

cockroach cert create-node \
  10.0.1.220 \
  localhost \
  $(hostname) \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

cockroach cert create-client root --certs-dir=certs --ca-key=my-safe-directory/ca.key
```

---

## Step 4: Create Certificates for db2 and db3 (still on db1)

### For db2 (10.0.2.43)
```bash
mkdir -p /var/lib/cockroach/db2-certs
cp certs/ca.crt /var/lib/cockroach/db2-certs/
cp certs/client.root.crt /var/lib/cockroach/db2-certs/
cp certs/client.root.key /var/lib/cockroach/db2-certs/

rm certs/node.crt certs/node.key

cockroach cert create-node \
  10.0.2.43 \
  localhost \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

cp certs/node.crt /var/lib/cockroach/db2-certs/
cp certs/node.key /var/lib/cockroach/db2-certs/
```

### For db3 (10.0.3.241)
```bash
mkdir -p /var/lib/cockroach/db3-certs
cp certs/ca.crt /var/lib/cockroach/db3-certs/
cp certs/client.root.crt /var/lib/cockroach/db3-certs/
cp certs/client.root.key /var/lib/cockroach/db3-certs/

rm certs/node.crt certs/node.key

cockroach cert create-node \
  10.0.3.241 \
  localhost \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

cp certs/node.crt /var/lib/cockroach/db3-certs/
cp certs/node.key /var/lib/cockroach/db3-certs/
```

### Recreate db1 node cert (we deleted it above)
```bash
rm certs/node.crt certs/node.key

cockroach cert create-node \
  10.0.1.220 \
  localhost \
  $(hostname) \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key
```

---

## Step 5: Copy Certificates to db2 and db3 (from db1)

### Copy to db2 (10.0.2.43)
```bash
scp -i /path/to/paris-key.pem /var/lib/cockroach/db2-certs/* ec2-user@10.0.2.43:/var/lib/cockroach/certs/
```

### Copy to db3 (10.0.3.241)
```bash
scp -i /path/to/paris-key.pem /var/lib/cockroach/db3-certs/* ec2-user@10.0.3.241:/var/lib/cockroach/certs/
```

### Fix permissions on db2 and db3 (SSH into each and run)
```bash
chmod 700 /var/lib/cockroach/certs
chmod 600 /var/lib/cockroach/certs/*
```

---

## Step 6: Start CockroachDB

### On db1 (10.0.1.220)
```bash
cd /var/lib/cockroach

cockroach start \
  --certs-dir=certs \
  --store=/var/lib/cockroach/data \
  --advertise-addr=10.0.1.220 \
  --listen-addr=10.0.1.220:26257 \
  --http-addr=10.0.1.220:8080 \
  --join=10.0.1.220:26257,10.0.2.43:26257,10.0.3.241:26257 \
  --background
```

### On db2 (10.0.2.43)
```bash
cd /var/lib/cockroach

cockroach start \
  --certs-dir=certs \
  --store=/var/lib/cockroach/data \
  --advertise-addr=10.0.2.43 \
  --listen-addr=10.0.2.43:26257 \
  --http-addr=10.0.2.43:8080 \
  --join=10.0.1.220:26257,10.0.2.43:26257,10.0.3.241:26257 \
  --background
```

### On db3 (10.0.3.241)
```bash
cd /var/lib/cockroach

cockroach start \
  --certs-dir=certs \
  --store=/var/lib/cockroach/data \
  --advertise-addr=10.0.3.241 \
  --listen-addr=10.0.3.241:26257 \
  --http-addr=10.0.3.241:8080 \
  --join=10.0.1.220:26257,10.0.2.43:26257,10.0.3.241:26257 \
  --background
```

---

## Step 7: Initialize Cluster (on db1 ONLY, one time)

```bash
cd /var/lib/cockroach

cockroach init --certs-dir=certs --host=10.0.1.220:26257
```

Expected: `Cluster successfully initialized`

---

## Step 8: Verify Cluster

```bash
cd /var/lib/cockroach

cockroach node status --certs-dir=certs --host=10.0.1.220:26257
```

Should show all 3 nodes as `is_live = true`

---

## Step 9: Access SQL Shell

```bash
cd /var/lib/cockroach

cockroach sql --certs-dir=certs --host=10.0.1.220:26257
```

### Create admin user for Web UI
```sql
CREATE USER max WITH PASSWORD 'max';
GRANT admin TO max;
```

---

## Step 10: Test

```sql
CREATE DATABASE testdb;
USE testdb;
CREATE TABLE accounts (id INT PRIMARY KEY, balance DECIMAL);
INSERT INTO accounts VALUES (1, 1000.50);
SELECT * FROM accounts;
```

### Access Web UI
Open in browser: `https://10.0.1.220:8080`
Login with user `max` / password `max`

---

## Quick Reference

| Node | IP | SQL Port | HTTP Port |
|------|------|----------|-----------|
| db1 | 10.0.1.220 | 26257 | 8080 |
| db2 | 10.0.2.43 | 26257 | 8080 |
| db3 | 10.0.3.241 | 26257 | 8080 |
