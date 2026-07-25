For Confirmation
### Phase 1 - Provisioning Infrastructure ✅

* Create VPC
* Create Subnets
* Create Internet Gateway
* Create Route Tables
* Create Security Groups
* Launch Node5 and Node6
* Configure VPC Peering

### Phase 2 - Install CockroachDB ✅

* Install CockroachDB
* Configure environment variables
* Create systemd service
* Start CockroachDB

### Phase 3 - Verify Cluster Membership

Check all nodes:

```bash
cockroach node status --insecure --host=10.10.1.10:26257
```

or

```sql
SHOW NODES;
```

Expected:

```
Node1  Live
Node2  Live
Node3  Live
Node4  Live
Node5  Live
Node6  Live
```

---

### Phase 4 - Check Replica Rebalancing

```sql
SHOW RANGES;
```

Observe:

* Replica movement
* Leaseholder movement
* Under-replicated ranges

---

### Phase 5 - Check Cluster Health

```sql
SHOW CLUSTER SETTING version;
```

```sql
SHOW CLUSTER QUERIES;
```

```sql
SHOW CLUSTER SESSIONS;
```

```sql
SHOW JOBS;
```

---

### Phase 6 - Check Admin UI

Open:

```
http://<Node1-IP>:8080
```

Verify:

* 6 Nodes
* Capacity
* Replication
* Network
* Stores
* Ranges

---

### Phase 7 - Verify Replica Distribution

Run:

```sql
SHOW RANGES FROM TABLE customers;
```

Look for:

* Lease Holder
* Replicas
* Voting Replicas

Ensure replicas are distributed across the new nodes.

---

### Phase 8 - Generate Load

Run a workload to force CockroachDB to rebalance.

Example:

```bash
cockroach workload init kv \
  --insecure \
  --host=10.10.1.10
```

Then:

```bash
cockroach workload run kv \
  --insecure \
  --host=10.10.1.10 \
  --duration=15m
```

---

### Phase 9 - Monitor Rebalancing

Watch node status repeatedly:

```bash
watch -n5 "cockroach node status --insecure --host=10.10.1.10:26257"
```

You'll see replicas moving as the cluster balances itself.

---

### Phase 10 - Verify Storage Distribution

```sql
SHOW RANGES;
```

Or from the Admin UI:

* Capacity
* Replicas
* QPS
* Leaseholders

The new nodes should gradually receive replicas.

---

