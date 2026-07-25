### Install CockroachDB and Join Node5 & Node6 (Insecure Mode)

Perform these steps on **Node5** and **Node6**.

---

### SSH to Node5

```bash
ssh -i cockroach.pem ubuntu@<Node5-Public-IP>
```

---

### Update the Server

```bash
sudo apt update
sudo apt upgrade -y
```

---

### Download CockroachDB

Replace the version with the one running on your existing cluster.

```bash
curl https://binaries.cockroachdb.com/cockroach-v25.2.3.linux-amd64.tgz | tar -xz
```

---

### 6.4 Install CockroachDB

```bash
sudo cp cockroach-v25.2.3.linux-amd64/cockroach /usr/local/bin/
sudo chmod +x /usr/local/bin/cockroach
```

Verify:

```bash
cockroach version
```

---

### 6.5 Create User and Directories

```bash
sudo useradd -m cockroach
sudo mkdir -p /var/lib/cockroach
sudo chown -R cockroach:cockroach /var/lib/cockroach
```

---

### 6.6 Set Environment Variables

```bash
sudo vi /etc/profile.d/cockroach.sh
```

Add:

```bash
export COCKROACH_CHANNEL=official-binary
export COCKROACH_SKIP_ENABLING_DIAGNOSTIC_REPORTING=true
export PATH=$PATH:/usr/local/bin
```

Save and reload:

```bash
source /etc/profile.d/cockroach.sh
```

Verify:

```bash
echo $PATH
```

---

### 6.7 Create the systemd Service

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
  --listen-addr=10.20.1.10:26257 \
  --advertise-addr=10.20.1.10:26257 \
  --http-addr=0.0.0.0:8080 \
  --join=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257
Restart=always
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

> **For Node6**, change:
>
> ```text
> --listen-addr=10.30.2.10:26257
> --advertise-addr=10.30.2.10:26257
> ```
>
> Keep the same `--join` list.

---

### Enable the Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable cockroach
sudo systemctl start cockroach
```

---

### Verify Service Status

```bash
sudo systemctl status cockroach
```

---

### Verify the Port

```bash
ss -tulnp | grep 26257
```

---

### Verify from the Existing Cluster

On Node1:

```bash
cockroach sql --insecure --host=10.10.1.10
```

Run:

```sql
SHOW NODES;
```

Expected output:

```
Node1   Live
Node2   Live
Node3   Live
Node4   Live
Node5   Live
Node6   Live
```

