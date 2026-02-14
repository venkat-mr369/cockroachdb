### Create CockroachDB systemd Service (run on ALL 3 nodes)

---

### Step 1: Create cockroach user (on ALL 3 nodes)

```bash
sudo useradd -r -s /bin/false cockroach
sudo chown -R cockroach:cockroach /var/lib/cockroach
```

---

### Step 2: Create service file

### On db1 (10.0.1.220)
```bash
sudo vi /etc/systemd/system/cockroachdb.service
```

Paste this:
```ini
[Unit]
Description=CockroachDB Server
Requires=network.target
After=network.target

[Service]
Type=notify
User=cockroach
Group=cockroach
WorkingDirectory=/var/lib/cockroach
ExecStart=/usr/local/bin/cockroach start \
  --certs-dir=/var/lib/cockroach/certs \
  --store=/var/lib/cockroach/data \
  --advertise-addr=10.0.1.220 \
  --listen-addr=10.0.1.220:26257 \
  --http-addr=10.0.1.220:8080 \
  --join=10.0.1.220:26257,10.0.2.43:26257,10.0.3.241:26257
ExecStop=/usr/local/bin/cockroach quit --certs-dir=/var/lib/cockroach/certs --host=10.0.1.220:26257
Restart=always
RestartSec=10
LimitNOFILE=65536
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

### On db2 (10.0.2.43)
```bash
sudo vi /etc/systemd/system/cockroachdb.service
```

Paste this:
```ini
[Unit]
Description=CockroachDB Server
Requires=network.target
After=network.target

[Service]
Type=notify
User=cockroach
Group=cockroach
WorkingDirectory=/var/lib/cockroach
ExecStart=/usr/local/bin/cockroach start \
  --certs-dir=/var/lib/cockroach/certs \
  --store=/var/lib/cockroach/data \
  --advertise-addr=10.0.2.43 \
  --listen-addr=10.0.2.43:26257 \
  --http-addr=10.0.2.43:8080 \
  --join=10.0.1.220:26257,10.0.2.43:26257,10.0.3.241:26257
ExecStop=/usr/local/bin/cockroach quit --certs-dir=/var/lib/cockroach/certs --host=10.0.2.43:26257
Restart=always
RestartSec=10
LimitNOFILE=65536
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

### On db3 (10.0.3.241)
```bash
sudo vi /etc/systemd/system/cockroachdb.service
```

Paste this:
```ini
[Unit]
Description=CockroachDB Server
Requires=network.target
After=network.target

[Service]
Type=notify
User=cockroach
Group=cockroach
WorkingDirectory=/var/lib/cockroach
ExecStart=/usr/local/bin/cockroach start \
  --certs-dir=/var/lib/cockroach/certs \
  --store=/var/lib/cockroach/data \
  --advertise-addr=10.0.3.241 \
  --listen-addr=10.0.3.241:26257 \
  --http-addr=10.0.3.241:8080 \
  --join=10.0.1.220:26257,10.0.2.43:26257,10.0.3.241:26257
ExecStop=/usr/local/bin/cockroach quit --certs-dir=/var/lib/cockroach/certs --host=10.0.3.241:26257
Restart=always
RestartSec=10
LimitNOFILE=65536
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

---

### Step 3: Stop existing cockroach process first (on ALL 3 nodes)

```bash
ps -ef | grep cockroach | grep -v grep
kill -TERM <PID>
```

---

### Step 4: Enable and start service (on ALL 3 nodes)

```bash
sudo systemctl daemon-reload
sudo systemctl enable cockroachdb
sudo systemctl start cockroachdb
```

---

### Step 5: Check status (on ALL 3 nodes)

```bash
sudo systemctl status cockroachdb
```

Should show `active (running)`

---

### Useful Commands

```bash
# Start
sudo systemctl start cockroachdb

# Stop
sudo systemctl stop cockroachdb

# Restart
sudo systemctl restart cockroachdb

# Check status
sudo systemctl status cockroachdb

# See logs
sudo journalctl -u cockroachdb -f

# See last 50 lines
sudo journalctl -u cockroachdb -n 50

# Check if enabled on boot
sudo systemctl is-enabled cockroachdb
```

---

### Step 6: Test auto-start by rebooting (on any one node)

```bash
sudo reboot
```

After reboot, SSH back in and check:
```bash
sudo systemctl status cockroachdb
```

Then from any node verify cluster:
```bash
cd /var/lib/cockroach
cockroach node status --certs-dir=certs --host=10.0.1.220:26257
```

All 3 nodes should show `is_live = true`.

---

### What each setting does

| Setting | Meaning |
|---------|---------|
| `Type=notify` | CockroachDB tells systemd when it's ready |
| `Restart=always` | If it crashes, auto-restart |
| `RestartSec=10` | Wait 10 seconds before restarting |
| `LimitNOFILE=65536` | Allow more open files (CockroachDB needs many) |
| `TimeoutStopSec=60` | Give 60 seconds for graceful shutdown |
| `WantedBy=multi-user.target` | Start on boot when system is ready |
