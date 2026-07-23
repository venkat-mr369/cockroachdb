
## Part 4 – Install CockroachDB and Join `crdb-node4`

### Prerequisites

* `crdb-node4` is running.
* Private IP: **10.10.4.10**
* Hostname: **crdb-node4**
* SSH access is working.
* Existing cluster:

  * Node1 → 10.10.1.10
  * Node2 → 10.10.2.10
  * Node3 → 10.10.3.10

---

# Step 1: SSH to Node4

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE4_PUBLIC_IP>
```

---

# Step 2: Set Hostname

```bash
sudo hostnamectl set-hostname crdb-node4
```

Verify:

```bash
hostname
```

Expected:

```text
crdb-node4
```

---

# Step 3: Update `/etc/hosts`

On **all four nodes**, ensure the following entries exist:

```text
10.10.1.10    crdb-node1
10.10.2.10    crdb-node2
10.10.3.10    crdb-node3
10.10.4.10    crdb-node4
```

Test:

```bash
ping -c 4 crdb-node1
ping -c 4 crdb-node2
ping -c 4 crdb-node3
```

---

# Step 4: Download the Same CockroachDB Version

Check the version on Node1:

```bash
cockroach version
```

Example:

```text
CockroachDB CCL v25.3.3
```

Download that exact version on Node4:

```bash
curl https://binaries.cockroachdb.com/cockroach-v25.3.3.linux-amd64.tgz | tar -xz
```

Install it:

```bash
sudo cp cockroach-v25.3.3.linux-amd64/cockroach /usr/local/bin/
sudo chmod +x /usr/local/bin/cockroach
```

Verify:

```bash
cockroach version
```

---

# Step 5: Create the CockroachDB User

If it doesn't already exist:

```bash
sudo useradd -m -s /bin/bash cockroach
```

Verify:

```bash
id cockroach
```

---

# Step 6: Create Directories

```bash
sudo mkdir -p /var/lib/cockroach
sudo mkdir -p /var/log/cockroach
```

Set ownership:

```bash
sudo chown -R cockroach:cockroach /var/lib/cockroach
sudo chown -R cockroach:cockroach /var/log/cockroach
```

Permissions:

```bash
sudo chmod 755 /var/lib/cockroach
sudo chmod 755 /var/log/cockroach
```

Verify:

```bash
ls -ld /var/lib/cockroach
ls -ld /var/log/cockroach
```

Expected:

```text
drwxr-xr-x ... cockroach cockroach /var/lib/cockroach
drwxr-xr-x ... cockroach cockroach /var/log/cockroach
```

---

# Step 7: Create the Systemd Service

Create:

```bash
sudo vi /etc/systemd/system/cockroach.service
```

Paste:

```ini
[Unit]
Description=CockroachDB
After=network.target

[Service]
Type=notify
User=cockroach
ExecStart=/usr/local/bin/cockroach start \
  --insecure \
  --store=/var/lib/cockroach \
  --listen-addr=10.10.4.10:26257 \
  --advertise-addr=10.10.4.10:26257 \
  --http-addr=10.10.4.10:8080 \
  --join=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257 \
  --log="file-defaults: {dir: '/var/log/cockroach'}"

Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

> If your existing nodes use a different logging configuration, copy the service file from Node1 and update only the IP address and `--join` list.

---

# Step 8: Reload systemd

```bash
sudo systemctl daemon-reload
```

Enable the service:

```bash
sudo systemctl enable cockroach
```

---

# Step 9: Start CockroachDB

```bash
sudo systemctl start cockroach
```

Check status:

```bash
sudo systemctl status cockroach
```

Expected:

```text
Active: active (running)
```

---

# Step 10: Monitor Logs

Follow the logs:

```bash
sudo journalctl -u cockroach -f
```

You should see messages indicating that the node has joined the existing cluster.

If you're using file logging, also check:

```bash
ls -lh /var/log/cockroach
```

Example:

```text
cockroach.log
cockroach-health.log
cockroach-sql.log
```

---

# Step 11: Verify from SQL

Connect to the cluster:

```bash
cockroach sql --insecure --host=10.10.1.10:26257
```

List nodes:

```sql
SELECT node_id,
       address,
       locality,
       is_live
FROM crdb_internal.gossip_nodes;
```

Or use the CLI:

```bash
cockroach node status \
  --host=10.10.1.10:26257 \
  --insecure
```

You should now see **4 live nodes**.

---

# Step 12: Verify in Admin UI

Open:

```text
http://10.10.1.10:8080
```

Go to:

**Overview → Nodes**

Expected:

```text
Node1  Live
Node2  Live
Node3  Live
Node4  Live
```

---

# Step 13: Observe Replica Rebalancing

Navigate to:

**Overview → Replication**

Watch:

* Replica count
* Leaseholder count
* Rebalancing activity

Initially, Node4 may have **0 replicas**.

After a few minutes, CockroachDB's allocator should begin moving replicas to Node4 automatically.

---

# Step 14: Verify Replica Distribution

Run:

```sql
SHOW RANGES FROM TABLE customers;
```

Also check:

```sql
SHOW RANGES FROM TABLE orders;
```

Over time, you'll see replicas assigned to Node4 as rebalancing progresses.

---

# Step 15: Verify Cluster Health

```bash
cockroach node status \
  --host=10.10.1.10:26257 \
  --insecure
```

Review:

* Node status
* Replica counts
* Capacity
* Live status

---

## Directory Layout

```text
/
├── usr
│   └── local
│       └── bin
│           └── cockroach
│
├── var
│   ├── lib
│   │   └── cockroach
│   │       ├── AUXILIARY
│   │       ├── MANIFEST-*
│   │       ├── CURRENT
│   │       ├── OPTIONS-*
│   │       └── *.sst
│   │
│   └── log
│       └── cockroach
│           ├── cockroach.log
│           ├── cockroach-health.log
│           └── cockroach-sql.log
│
└── etc
    └── systemd
        └── system
            └── cockroach.service
```

---

## Expected Result

After completing these steps:

* ✅ `crdb-node4` is running CockroachDB.
* ✅ It has joined the existing 3-node cluster.
* ✅ Admin UI shows **4 live nodes**.
* ✅ Replicas begin moving to Node4 automatically.
* ✅ Leaseholders are gradually redistributed.
* ✅ The cluster expands from **3 nodes to 4 nodes** with no application downtime.
