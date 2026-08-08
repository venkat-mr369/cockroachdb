### Create Mumbai Primary Cluster (2 Nodes)
```
          Primary Cluster
             Mumbai
+-----------------------------+
| 10.10.1.10                  |
| 10.10.2.10                  |
+-----------------------------+
             ||
             || Physical Cluster Replication
             ||
+-----------------------------+
| 10.30.1.10                  |
| 10.30.2.10                  |
+-----------------------------+
          Standby Cluster
           Singapore

```

### Mumbai Node 1 (10.10.1.10)

Edit:

```bash
sudo vi /etc/default/cockroach
```

```bash
NODE_IP=10.10.1.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257
LOCALITY=region=mumbai,zone=mumbai-a
```

---

### Mumbai Node 2 (10.10.2.10)

```bash
sudo vi /etc/default/cockroach
```

```bash
NODE_IP=10.10.2.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257
LOCALITY=region=mumbai,zone=mumbai-b
```

---

### Create Singapore Standby Cluster (2 Nodes)

### Singapore Node 1 (10.30.1.10)

```bash
sudo vi /etc/default/cockroach
```

```bash
NODE_IP=10.30.1.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.30.1.10:26257,10.30.2.10:26257
LOCALITY=region=singapore,zone=singapore-a
```

---

### Singapore Node 2 (10.30.2.10)

```bash
sudo vi /etc/default/cockroach
```

```bash
NODE_IP=10.30.2.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.30.1.10:26257,10.30.2.10:26257
LOCALITY=region=singapore,zone=singapore-b
```

---

### Clean Old Cluster Data

Run on **all four servers**.

Stop CockroachDB:

```bash
sudo systemctl stop cockroach
```

Verify:

```bash
sudo systemctl status cockroach
```

Remove old cluster data:

```bash
sudo rm -rf /var/lib/cockroach/data
sudo rm -rf /var/lib/cockroach/logs
```

Create new directories:

```bash
sudo mkdir -p /var/lib/cockroach/data
sudo mkdir -p /var/lib/cockroach/logs
```

Assign ownership:

```bash
sudo chown -R cockroach:cockroach /var/lib/cockroach
```

Reload systemd:

```bash
sudo systemctl daemon-reload
```

---

### Start the Mumbai Cluster

On **both Mumbai nodes**:

```bash
sudo systemctl start cockroach
```

Check status:

```bash
sudo systemctl status cockroach
```

Both services should be **active (running)**.

---

### Initialize the Mumbai Cluster

Run **only once** from **10.10.1.10**:

```bash
cockroach init --insecure --host=10.10.1.10
```

Expected output:

```text
Cluster successfully initialized
```

In Node 2, Repeat

```
sudo systemctl stop cockroach
sudo rm -rf /var/lib/cockroach/data
sudo rm -rf /var/lib/cockroach/logs
sudo mkdir -p /var/lib/cockroach/data
sudo mkdir -p /var/lib/cockroach/logs
sudo chown -R cockroach:cockroach /var/lib/cockroach
```
```
sudo systemctl start cockroach
```

---

## Verify the Mumbai Cluster

Connect:

```bash
cockroach node status --host=10.10.1.10:26257 --insecure
```
Expected:

```text
  id |     address      |   sql_address    |  build  |              started_at              |              updated_at              |            locality            | is_available | is_live
-----+------------------+------------------+---------+--------------------------------------+--------------------------------------+--------------------------------+--------------+----------
   1 | 10.10.1.10:26257 | 10.10.1.10:26257 | v25.2.2 | 2026-08-08 04:36:35.518003 +0000 UTC | 2026-08-08 04:45:05.600976 +0000 UTC | region=mumbai,zone=mumbai-3hub | true         | true
   2 | 10.10.2.10:26257 | 10.10.2.10:26257 | v25.2.2 | 2026-08-08 04:40:16.843455 +0000 UTC | 2026-08-08 04:45:04.909075 +0000 UTC | region=mumbai,zone=mumbai-4hub | true         | true
(2 rows)
```
Connect & Run:
```
cockroach sql --insecure --host=10.10.1.10:26257
```

```sql
SELECT node_id, address, locality, server_version FROM crdb_internal.kv_node_status;
```

```
  node_id |     address      |            locality            | server_version
----------+------------------+--------------------------------+-----------------
        1 | 10.10.1.10:26257 | region=mumbai,zone=mumbai-1hub | 25.2
        2 | 10.10.2.10:26257 | region=mumbai,zone=mumbai-2hub | 25.2
(2 rows)
```

Verify the Cluster ID:

```sql
SELECT crdb_internal.cluster_id();
```

Save this Cluster ID.

---

### Start the Singapore Cluster

On **both Singapore nodes**:

```bash
sudo systemctl start cockroach
```

Verify:

```bash
sudo systemctl status cockroach
```

---

### Initialize the Singapore Cluster

Run **only once** from **10.30.1.10**:

```bash
cockroach init --insecure --host=10.30.1.10:26257
```

Expected:

```text
Cluster successfully initialized
```

---

### Verify the Singapore Cluster

Connect:

```bash
cockroach sql --insecure --host=10.30.1.10:26257
```

Run:

```sql
SHOW NODES;
```

Expected:

```text
node_id | address
--------+------------------
1       | 10.30.1.10
2       | 10.30.2.10
```

Check the Cluster ID:

```sql
SELECT crdb_internal.cluster_id();
```

This **must be different** from the Mumbai Cluster ID.

---

### Apply the Enterprise License

On **both clusters**, run:

```sql
SET CLUSTER SETTING enterprise.license = 'crl-0-EODQ6NQGGAQyEH0vajlANUndqwNHF/AFHQ86EJOHfsC09EVVuYk4nCukzvE';
```

Verify:

```sql
SHOW CLUSTER SETTING enterprise.license;
```

---

### At this point

You will have:

```text
Cluster 1 (Primary)
===================
10.10.1.10
10.10.2.10

Cluster ID : AAAAAAAA

-------------------------------

Cluster 2 (Standby)
===================
10.30.1.10
10.30.2.10

Cluster ID : BBBBBBBB
```

These are now independent clusters and are the correct path for testing Physical Cluster Replication.

### Next step

After you've completed these steps, share the output of:

```sql
SELECT crdb_internal.cluster_id();
```

