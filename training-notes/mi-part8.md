## AWS CLI Lab – adding Node 4 & Installation of CockroachDB

## Add CockroachDB Node-4 (Manual)

> **Prerequisites**
>
> Completed Parts 1–4.
>
> Existing Cluster:
>
> * crdb-node1 → 10.10.1.10
> * crdb-node2 → 10.10.2.10
> * crdb-node3 → 10.10.3.10
>
> New Node:
>
> * crdb-node4 → 10.10.4.10

---

## Step 45: SSH to Node-4

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE4_PUBLIC_IP>
```

---

## Step 46: Update Ubuntu

```bash
sudo apt update

sudo apt upgrade -y
```

---

## Step 47: Install Required Packages

```bash
sudo apt install -y \
curl \
wget \
tar \
jq \
vim \
unzip \
net-tools \
dnsutils \
ca-certificates
```

Verify

```bash
curl --version

wget --version
```

---

## Step 48: Download CockroachDB

Use the **same version** as the existing cluster.

```bash
cd /tmp

wget https://binaries.cockroachdb.com/cockroach-v25.2.2.linux-amd64.tgz
```

Extract

```bash
tar -xzf cockroach-v25.2.2.linux-amd64.tgz
```

Copy Binary

```bash
sudo cp cockroach-v25.2.2.linux-amd64/cockroach /usr/local/bin/
```

Verify

```bash
cockroach version
```

---

## Step 49: Create CockroachDB User

```bash
sudo useradd --system \
--home /var/lib/cockroach \
--shell /bin/bash cockroach
```

Verify

```bash
id cockroach
```

---

## Step 50: Create Directory Structure

```bash
sudo mkdir -p /var/lib/cockroach/data

sudo mkdir -p /var/lib/cockroach/logs

sudo chown -R cockroach:cockroach /var/lib/cockroach

sudo chmod 750 /var/lib/cockroach
```

Verify

```bash
sudo ls -ld /var/lib/cockroach
```

---

## Step 51: Configure Hostname

```bash
sudo hostnamectl set-hostname crdb-node4
```

Verify

```bash
hostname

cat /etc/hostname
```

Expected

```text
crdb-node4
```

---

## Step 52: Update `/etc/hosts`

Update **all four nodes**.

```bash
sudo vi /etc/hosts
```

Contents

```text
127.0.0.1 localhost

10.10.1.10 crdb-node1
10.10.2.10 crdb-node2
10.10.3.10 crdb-node3
10.10.4.10 crdb-node4
```

Verify

```bash
cat /etc/hosts
```

Test

```bash
ping -c 4 crdb-node1
ping -c 4 crdb-node2
ping -c 4 crdb-node3
```

---

## Step 53: Create Environment File

```bash
sudo vi /etc/default/cockroach
```

Contents

```text
NODE_IP=10.10.4.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257
```

> **Note:** The `JOIN_NODES` list contains the existing cluster nodes. The new node contacts these nodes to join the cluster.

---

## Step 54: Create systemd Service

```bash
sudo vi /etc/systemd/system/cockroach.service
```

Paste

```ini
[Unit]
Description=CockroachDB Database
After=network-online.target
Wants=network-online.target

[Service]
Type=notify

User=cockroach
Group=cockroach

EnvironmentFile=/etc/default/cockroach

ExecStart=/usr/local/bin/cockroach start \
 --insecure \
 --store=${DATA_DIR} \
 --listen-addr=0.0.0.0:26257 \
 --advertise-addr=${NODE_IP}:26257 \
 --http-addr=0.0.0.0:8080 \
 --join=${JOIN_NODES} \
 --log-dir=${LOG_DIR}

Restart=always
RestartSec=5

LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
```

> This is identical to the service used on Nodes 1–3. The only difference is the values in `/etc/default/cockroach`.

---

## Step 55: Enable and Start Service

```bash
sudo systemctl daemon-reload

sudo systemctl enable cockroach

sudo systemctl start cockroach
```

---

## Step 56: Verify Service

```bash
sudo systemctl status cockroach --no-pager
```

Expected

```text
Active: active (running)
```

Verify Binary

```bash
cockroach version
```

Verify SQL Port

```bash
ss -lnt | grep 26257
```

Verify Admin UI Port

```bash
ss -lnt | grep 8080
```

---

## Step 57: Verify Node Joined the Cluster

From **Node-1**:

```bash
cockroach node status \
  --host=10.10.1.10:26257 \
  --insecure
```

Expected

```text
Node ID   Address           Build    Updated At
----------------------------------------------------------
1         10.10.1.10:26257
2         10.10.2.10:26257
3         10.10.3.10:26257
4         10.10.4.10:26257
```

---

## Step 58: Verify in Admin UI

Open

```
http://<Node1_Public_IP>:8080
```

Navigate to:

```
Overview
    ↓
Nodes
```

Verify

```text
✓ Node1 - Live
✓ Node2 - Live
✓ Node3 - Live
✓ Node4 - Live
```

---

## Step 59: Observe Automatic Replica Rebalancing

Open

```
Overview
    ↓
Replication
```

Observe:

* Replica Count
* Leaseholder Count
* Rebalancing Activity

Initially, Node4 may have zero replicas. Over the next few minutes, CockroachDB's allocator will automatically move replicas to Node4 to balance the cluster.

---

## Completed Part 4A

At this stage:

* ✅ CockroachDB installed on **Node4**
* ✅ `cockroach` system user created
* ✅ Data directory (`/var/lib/cockroach/data`) created
* ✅ Log directory (`/var/lib/cockroach/logs`) created
* ✅ Hostname configured as `crdb-node4`
* ✅ `/etc/hosts` updated on all four nodes
* ✅ `/etc/default/cockroach` created for Node4
* ✅ `cockroach.service` configured using the same template as Nodes 1–3
* ✅ Node4 joined the existing cluster
* ✅ Admin UI shows **4 live nodes**
* ✅ Automatic replica rebalancing begins

This version matches the structure and conventions used throughout your existing lab manual, so students will see a consistent workflow when expanding the cluster.
