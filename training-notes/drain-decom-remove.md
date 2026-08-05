**6-node CockroachDB cluster** is already running.


1. Drain Node
2. Decommission Node
3. Recommission Node
4. Remove Node
5. Add Node Back

These are different operations in CockroachDB.

---

## Lab 1: Gracefully Drain a Node

Suppose we want to drain **Node5 (10.30.1.10)**.

### Step 1: Verify Cluster

```bash
cockroach node status \
  --insecure \
  --host=10.10.1.10:26257
```

---

### Step 2: SSH to Node5

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE5_PUBLIC_IP>
```

---

### Step 3: Drain Node5

```bash
cockroach node drain \
  --insecure \
  --host=10.30.1.10:26257 \
  --self
```

or if running as a service:

```bash
sudo systemctl stop cockroach
```

Observe in the Admin UI:

```text
LIVE
   ↓
DRAINING
```

Existing SQL sessions finish gracefully.

---

### Step 4: Verify

From Node1:

```bash
cockroach node status \
  --insecure \
  --host=10.10.1.10:26257
```

---

## Lab 2: Decommission a Node

> A decommissioned node is permanently removed from the cluster after its replicas are relocated.

### Step 1: Find Node IDs

```bash
cockroach node status \
  --insecure \
  --host=10.10.1.10:26257
```

Example:

```text
Node1  id=1
Node2  id=2
Node3  id=3
Node4  id=4
Node5  id=5
Node6  id=6
```

---

### Step 2: Decommission Node5

```bash
cockroach node decommission 5 \
  --insecure \
  --host=10.10.1.10:26257
```

---

### Step 3: Watch Progress

```bash
cockroach node status \
  --decommission \
  --insecure \
  --host=10.10.1.10:26257
```

Observe:

```text
Membership : decommissioning
Replicas    : decreasing
```

CockroachDB automatically moves replicas from Node5 to other nodes.

---

### Step 4: Wait Until Complete

Eventually:

```text
Membership

decommissioned
```

Replicas:

```text
0
```

---

### Step 5: Verify

```bash
cockroach node status \
  --insecure \
  --host=10.10.1.10:26257
```

Node5 should show:

```text
Membership

decommissioned
```

---

## Lab 3: Recommission

Only works **before** decommission completes.

If Node5 is still in:

```text
decommissioning
```

Run:

```bash
cockroach node recommission 5 \
  --insecure \
  --host=10.10.1.10:26257
```

Verify:

```bash
cockroach node status \
  --decommission \
  --insecure \
  --host=10.10.1.10:26257
```

Membership returns to:

```text
active
```

---

## Lab 4: Verify Replica Movement

Before decommission:

```sql
SHOW RANGES FROM TABLE customers;
```

During decommission:

```sql
SHOW RANGES FROM TABLE customers;
```

Observe:

* Replica relocation
* Leaseholder movement

---

## Lab 5: Remove the VM

After Node5 is completely decommissioned:

```bash
sudo systemctl stop cockroach
```

Terminate the EC2 instance:

```bash
aws ec2 terminate-instances \
  --region ap-southeast-1 \
  --instance-ids <INSTANCE-ID>
```

---

## Lab 6: Add Node Again

Launch a new VM.

Install CockroachDB.

Use:

```bash
--join=10.10.1.10:26257,10.10.2.10:26257,10.10.3.10:26257,10.10.4.10:26257,10.30.2.10:26257
```

The new node automatically joins the cluster.

---

### Drain

```bash
cockroach node drain \
  --self \
  --insecure \
  --host=<NODE-IP>:26257
```

### Decommission

```bash
cockroach node decommission <NODE-ID> \
  --insecure \
  --host=10.10.1.10:26257
```

### Monitor

```bash
cockroach node status \
  --decommission \
  --insecure \
  --host=10.10.1.10:26257
```

### Recommission

```bash
cockroach node recommission <NODE-ID> \
  --insecure \
  --host=10.10.1.10:26257
```

### Check Cluster

```bash
cockroach node status \
  --insecure \
  --host=10.10.1.10:26257
```

* Replicas moved to other nodes
* Node removed from cluster membership
* Cannot rejoin with the old identity after decommission completes
* Requires a fresh join to become a new cluster member


### Check SQL

```sql
SHOW NODES;
```

