To configure **localities**, you must restart each CockroachDB node with the `--locality` flag. 

Note:- You **cannot change locality dynamically** using SQL.

Your mapping will be:

| Node  | Private IP | Locality                            |
| ----- | ---------- | ----------------------------------- |
| Node1 | 10.10.1.10 | `region=mumbai,zone=mumbai-a`       |
| Node2 | 10.10.2.10 | `region=mumbai,zone=mumbai-b`       |
| Node3 | 10.10.3.10 | `region=mumbai,zone=mumbai-c`       |
| Node4 | 10.10.4.10 | `region=mumbai,zone=mumbai-d`       |
| Node5 | 10.30.1.10 | `region=singapore,zone=singapore-a` |
| Node6 | 10.30.2.10 | `region=singapore,zone=singapore-b` |

## Step 1: Update the Environment File

### Node1

```bash
sudo vi /etc/default/cockroach
```

```text
NODE_IP=10.10.1.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257,10.30.1.10:26257,10.30.2.10:26257
LOCALITY=region=mumbai,zone=mumbai-a
```

---

### Node2

```text
NODE_IP=10.10.2.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257,10.30.1.10:26257,10.30.2.10:26257
LOCALITY=region=mumbai,zone=mumbai-b
```

---

### Node3

```text
NODE_IP=10.10.3.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257,10.30.1.10:26257,10.30.2.10:26257
LOCALITY=region=mumbai,zone=mumbai-c
```

---

### Node4

```text
NODE_IP=10.10.4.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257,10.30.1.10:26257,10.30.2.10:26257
LOCALITY=region=mumbai,zone=mumbai-d
```

---

### Node5

```text
NODE_IP=10.30.1.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257,10.30.1.10:26257,10.30.2.10:26257
LOCALITY=region=singapore,zone=singapore-a
```

---

### Node6

```text
NODE_IP=10.30.2.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257,10.30.1.10:26257,10.30.2.10:26257
LOCALITY=region=singapore,zone=singapore-b
```

---

## Step 2: Update the systemd Service

Edit:

```bash
sudo vi /etc/systemd/system/cockroach.service
```

In the `ExecStart` section, add:

```bash
--locality=${LOCALITY} \
```

Example:

```ini
ExecStart=/usr/local/bin/cockroach start \
 --insecure \
 --store=/var/lib/cockroach/data \
 --listen-addr=0.0.0.0:26257 \
 --advertise-addr=${NODE_IP}:26257 \
 --http-addr=0.0.0.0:8080 \
 --join=${JOIN_NODES} \
 --locality=${LOCALITY} \
 --log-dir=/var/lib/cockroach/logs
```

---

## Step 3: Restart CockroachDB

Run on **each node**:

```bash
sudo systemctl daemon-reload

sudo systemctl restart cockroach

sudo systemctl status cockroach
```

---

## Step 4: Verify Localities

From Node1:

```bash
cockroach node status \
  --insecure \
  --host=10.10.1.10:26257
```

Or in the SQL shell:

```bash
cockroach sql --insecure --host=10.10.1.10:26257
```

Run:

```sql
SELECT node_id, locality
FROM crdb_internal.kv_node_status
ORDER BY node_id;
```

Expected output:

```text
node_id | locality
--------+-------------------------------------
1       | region=mumbai,zone=mumbai-a
2       | region=mumbai,zone=mumbai-b
3       | region=mumbai,zone=mumbai-c
4       | region=mumbai,zone=mumbai-d
5       | region=singapore,zone=singapore-a
6       | region=singapore,zone=singapore-b
```

After this is working, you can proceed with creating a **multi-region database**, adding regions, configuring **survival goals**, and experimenting with **REGIONAL BY TABLE**, **REGIONAL BY ROW**, and **GLOBAL** tables.
