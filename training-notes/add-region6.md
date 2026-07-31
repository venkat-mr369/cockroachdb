### SSH to the Servers

### Node-5

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE5_PUBLIC_IP>
```

### Node-6

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE6_PUBLIC_IP>
```
---

### Test Network Connectivity

From **Node1**:

```bash
ping 10.30.1.10
```

```bash
ping 10.30.2.10
```

From **Node5**:

```bash
ping 10.10.1.10
```

```bash
ping 10.10.2.10
```

Test the CockroachDB SQL port:

```bash
nc -zv 10.10.1.10 26257
```

```bash
nc -zv 10.30.1.10 26257
```

---

## Step 102: Update Ubuntu

```bash
sudo apt update

sudo apt upgrade -y
```

---

## Step 103: Install Required Packages

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

## Step 104: Download CockroachDB

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

## Step 105: Create CockroachDB User

```bash
sudo useradd --system --home /var/lib/cockroach --shell /bin/bash cockroach
```

Verify

```bash
id cockroach
```

---

## Step 106: Create Directory Structure

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

## Step 107: Configure Hostname

### Node-5

```bash
sudo hostnamectl set-hostname crdb-node5
```

### Node-6

```bash
sudo hostnamectl set-hostname crdb-node6
```

Verify

```bash
hostname

cat /etc/hostname
```

---

## Step 108: Configure Hosts File

```bash
sudo vi /etc/hosts
```

Add

```text
127.0.0.1 localhost

10.10.1.10 crdb-node1
10.10.2.10 crdb-node2
10.10.3.10 crdb-node3
10.10.4.10 crdb-node4
10.20.1.10 crdb-node5
10.20.2.10 crdb-node6
```

Verify

```bash
cat /etc/hosts
```

---

## Step 109: Create Environment File

### Node-5

```bash
sudo vi /etc/default/cockroach
```

```text
NODE_IP=10.20.1.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257
```

### Node-6

```text
NODE_IP=10.20.2.10
DATA_DIR=/var/lib/cockroach/data
LOG_DIR=/var/lib/cockroach/logs
JOIN_NODES=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257
```

---

## Step 110: Create systemd Service

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

## Step 111: Enable and Start Service

```bash
sudo systemctl daemon-reload

sudo systemctl enable cockroach

sudo systemctl start cockroach
```

---

## Step 112: Verify Node5 and Node6

Verify Service

```bash
sudo systemctl status cockroach --no-pager
```

Verify Binary

```bash
cockroach version
```

Verify SQL Port

```bash
ss -lnt | grep 26257
```

Verify Admin UI

```bash
ss -lnt | grep 8080
```

---

# Verify the Existing Cluster

Run the following **only on Node1**.

## Check All Nodes

```bash
cockroach node status \
  --insecure \
  --host=10.10.1.10:26257
```

Expected

```text
Node1
Node2
Node3
Node4
Node5
Node6
```

---

## Connect to SQL

```bash
cockroach sql \
  --insecure \
  --host=10.10.1.10:26257
```

Run

```sql
SHOW NODES;
```

Expected

```text
node_id | address        | is_live
--------+----------------+---------
1       | 10.10.1.10     | true
2       | 10.10.2.10     | true
3       | 10.10.3.10     | true
4       | 10.10.4.10     | true
5       | 10.20.1.10     | true
6       | 10.20.2.10     | true
```

> **Important:** Since the cluster was already initialized when Node1–Node4 were created, **do not run `cockroach init` again**. Node5 and Node6 automatically join the existing cluster using the `--join` addresses in the service configuration.


