### AWS CLI Lab – Part 5

### Install and Configure CockroachDB on All Three Nodes (Manual)

> Perform **Steps 33–44 on Node1, Node2, and Node3** unless noted otherwise.

---

## Step 33: SSH to the Server

Node-1

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE1_PUBLIC_IP>
```

Node-2

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE2_PUBLIC_IP>
```

Node-3

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE3_PUBLIC_IP>
```

---

## Step 34: Update Ubuntu

```bash
sudo apt update

sudo apt upgrade -y
```

---

## Step 35: Install Required Packages

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

## Step 36: Download CockroachDB

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

## Step 37: Create CockroachDB User

```bash
sudo useradd \
--system \
--home /var/lib/cockroach \
--shell /bin/bash \
cockroach
```

Verify

```bash
id cockroach
```

---

## Step 38: Create Directory Structure

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

## Step 39: Configure Hostname

### Node-1

```bash
sudo hostnamectl set-hostname crdb-node1
```

### Node-2

```bash
sudo hostnamectl set-hostname crdb-node2
```

### Node-3

```bash
sudo hostnamectl set-hostname crdb-node3
```

Verify

```bash
hostname

cat /etc/hostname
```

---

## Step 40: Configure Hosts File

Edit

```bash
sudo vi /etc/hosts
```

Add

```text
127.0.0.1 localhost

10.10.1.10 crdb-node1
10.10.2.10 crdb-node2
10.10.3.10 crdb-node3
```

Verify

```bash
cat /etc/hosts
```

---

## Step 41: Create Environment File

### Node-1

```bash
sudo vi /etc/default/cockroach
```

```text
NODE_IP=10.10.1.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257
```

### Node-2

```text
NODE_IP=10.10.2.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257
```

### Node-3

```text
NODE_IP=10.10.3.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257
```

---

## Step 42: Create systemd Service

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
 --store=/var/lib/cockroach/data \
 --listen-addr=0.0.0.0:26257 \
 --advertise-addr=${NODE_IP}:26257 \
 --http-addr=0.0.0.0:8080 \
 --join=${JOIN_NODES} \
 --log-dir=/var/lib/cockroach/logs

Restart=always
RestartSec=5

LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
```

---

## Step 43: Enable and Start Service

```bash
sudo systemctl daemon-reload

sudo systemctl enable cockroach

sudo systemctl start cockroach
```

---

## Step 44: Verify Service (Run on All Three Nodes)

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

## End of Part 4

At this stage:

* ✅ CockroachDB installed on all three nodes
* ✅ `cockroach` system user created
* ✅ Data and log directories created
* ✅ Hostnames configured
* ✅ `/etc/hosts` configured
* ✅ `cockroach.service` created
* ✅ `systemd` service enabled
* ✅ All three services running and listening on ports **26257** and **8080**

The cluster has **not** been initialized yet.

### On Node 1
aws ec2 describe-instances --filters "Name=tag:Name,Values=crdb-node*" --query "Reservations[].Instances[].{Name:Tags[0].Value,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}" --output table

```output
------------------------------------------------
|               DescribeInstances              |
+------------+--------------+------------------+
|    Name    |  PrivateIP   |    PublicIP      |
+------------+--------------+------------------+
|  crdb-node3|  10.10.3.10  |  3.110.226.138   |
|  crdb-node2|  10.10.2.10  |  13.201.227.212  |
|  crdb-node1|  10.10.1.10  |  3.111.218.94    |
+------------+--------------+------------------+
```
### Init Cluster
You're right. I skipped one important operational step. Students need to know **how to connect to the node before running `cockroach init`**.

I'd revise **Part 5** like this.

---

# Part 5 – Initialize and Verify CockroachDB Cluster

## Step 45: Get Public IP Addresses

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=crdb-node*" \
  --query "Reservations[].Instances[].{Name:Tags[0].Value,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}" \
  --output table
```

Example

```text
----------------------------------------------------------
| Name        | PublicIP       | PrivateIP     |
----------------------------------------------------------
| crdb-node1  | 13.233.xx.xx   | 10.10.1.10    |
| crdb-node2  | 3.110.xx.xx    | 10.10.2.10    |
| crdb-node3  | 15.206.xx.xx   | 10.10.3.10    |
----------------------------------------------------------
```

---
### Step 49: Initialize the Cluster (Run Only Once)

> **Run this command only on Node-1.**

```bash
cockroach init --insecure --host=10.10.1.10:26257
```

Expected

```text
Cluster successfully initialized
```

> **Important:** Never run `cockroach init` again. The cluster only needs to be initialized once.

---

## Step 50: Verify Cluster Nodes

```bash
cockroach node status --insecure --host=10.10.1.10:26257
```

Expected

```text
3 rows

Node1
Node2
Node3
```

All nodes should show:

```text
is_live       = true
is_available  = true
```

---

## Step 51: Connect to SQL Shell

```bash
cockroach sql --insecure --host=10.10.1.10:26257
```

Prompt

```text
root@10.10.1.10:26257/defaultdb>
```

---

After this, continue with:

* Create Database
* Create Table
* Insert Data
* Query Data
* Admin UI
* Failover Demo

---

**workflow diagram** 

```text
VM1  ✓ Running
VM2  ✓ Running
VM3  ✓ Running
        │
        ▼
SSH to Node-1
        │
        ▼
Verify CockroachDB Service
        │
        ▼
cockroach init (Only Once)
        │
        ▼
Verify 3 Nodes
        │
        ▼
Connect SQL Shell
        │
        ▼
Create Database
        │
        ▼
Open Admin UI
```


