 **Node Drain and Decommission**. In CockroachDB, **draining** and **decommissioning** are separate operations:

* **Drain**: Gracefully stops accepting new SQL connections and transfers leases before shutdown. It is used for planned maintenance.
* **Decommission**: Permanently removes a node from the cluster. Replicas are moved to other nodes before the node is removed.

> **Prerequisite:** This lab assumes your cluster now has **4 nodes**, so removing Node3 still leaves three nodes in the cluster.

```
Node1 → 10.10.1.10
Node2 → 10.10.2.10
Node3 → 10.10.3.10   ← Drain & Decommission
Node4 → 10.10.4.10
```

---

### AWS CLI Lab – Drain and Decommission `crdb-node3`

## Objective

Learn how to:

* Gracefully drain a CockroachDB node
* Observe lease transfers
* Decommission a node
* Verify replica rebalancing
* Verify cluster health after node removal

---

## Architecture Before Decommission

```text
               CockroachDB Cluster

        +------------------------------+
        | Node1  10.10.1.10            |
        +------------------------------+

        +------------------------------+
        | Node2  10.10.2.10            |
        +------------------------------+

        +------------------------------+
        | Node3  10.10.3.10            |  ← Remove
        +------------------------------+

        +------------------------------+
        | Node4  10.10.4.10            |
        +------------------------------+
```

---

# Step 1: Verify Cluster Health

Run from Node1:

```bash
cockroach node status \
  --host=10.10.1.10:26257 \
  --insecure
```

Expected:

```text
Node1  Live
Node2  Live
Node3  Live
Node4  Live
```

---

# Step 2: Find the Node ID

The decommission command requires the **node ID**, not the hostname.

```bash
cockroach node status \
  --host=10.10.1.10:26257 \
  --insecure
```

Example:

```text
ID  Address
1   10.10.1.10:26257
2   10.10.2.10:26257
3   10.10.3.10:26257
4   10.10.4.10:26257
```

Node ID = **3**

---

# Step 3: Drain Node3

SSH to Node3:

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE3_PUBLIC_IP>
```

Run:

```bash
cockroach node drain \
  --insecure \
  --host=10.10.3.10:26257 \
  --self
```

This will:

* Stop accepting new SQL client connections.
* Allow existing SQL sessions to finish.
* Transfer SQL leases and other work where possible.

Wait until the command completes successfully.

---

# Step 4: Stop the CockroachDB Service

```bash
sudo systemctl stop cockroach
```

Verify:

```bash
sudo systemctl status cockroach --no-pager
```

Expected:

```text
Active: inactive (dead)
```

---

Resuming to normal node operation.

```
cockroach node drain \
  --insecure \
  --host=10.10.3.10:26257 \
  --self \
  --undo
```

```bash
sudo systemctl stop cockroach
```


### Step 5: Decommission Node3

Run this command from any **live node** (for example, Node1):

```bash
cockroach node decommission 3 \
  --host=10.10.1.10:26257 \
  --insecure
```

CockroachDB will begin transferring replicas from Node3 to Nodes 1, 2, and 4.

---

# Step 6: Monitor Decommission Progress

```bash
cockroach node status \
  --host=10.10.1.10:26257 \
  --insecure
```

You can also monitor the Admin UI:

```
Overview
    ↓
Nodes
```

Watch:

* Replica count on Node3 decreasing
* Replica counts on Nodes 1, 2, and 4 increasing

---

# Step 7: Wait Until Complete

Continue checking:

```bash
cockroach node status \
  --host=10.10.1.10:26257 \
  --insecure
```

The node should eventually show as decommissioned.

---

# Step 8: Verify Cluster

Connect to SQL:

```bash
cockroach sql \
  --host=10.10.1.10:26257 \
  --insecure
```

Check that the cluster is still operational:

```sql
SELECT count(*) FROM customers;

SELECT count(*) FROM orders;

SELECT count(*) FROM employees;
```

All queries should succeed.

---

# Step 9: Verify Admin UI

Open:

```
http://<NODE1_PUBLIC_IP>:8080
```

Navigate to:

```
Overview
    ↓
Nodes
```

Expected:

* Node1 → Live
* Node2 → Live
* Node4 → Live
* Node3 → Decommissioned (or removed after the process completes)

---

# Step 10: Verify Replica Rebalancing

Open:

```
Overview
    ↓
Replication
```

Observe:

* Replica movement
* Leaseholder redistribution
* No under-replicated ranges after the process completes

---

# Step 11: (Optional) Terminate the EC2 Instance

Once the node is fully decommissioned, you can remove the infrastructure.

```bash
aws ec2 terminate-instances \
  --instance-ids $NODE3_INSTANCE
```

Verify:

```bash
aws ec2 describe-instances \
  --instance-ids $NODE3_INSTANCE \
  --query "Reservations[].Instances[].State.Name"
```

Expected:

```text
terminated
```

---

# Verify the Final Cluster

```bash
cockroach node status \
  --host=10.10.1.10:26257 \
  --insecure
```

Expected:

```text
ID   Address             Status
1    10.10.1.10:26257    Live
2    10.10.2.10:26257    Live
4    10.10.4.10:26257    Live
```

---

# Architecture After Decommission

```text
               CockroachDB Cluster

        +------------------------------+
        | Node1  10.10.1.10            |
        +------------------------------+

        +------------------------------+
        | Node2  10.10.2.10            |
        +------------------------------+

        +------------------------------+
        | Node4  10.10.4.10            |
        +------------------------------+

      Node3 Removed from Cluster
```

---

## Important Notes

* **Drain** is used for **planned maintenance**. If the node will return to the cluster, stop after draining and shutting it down—**do not decommission it**.
* **Decommission** is **permanent**. Once completed, that node cannot simply be started again and rejoin the cluster with its old identity. If you want it back, you should wipe its data directory and add it as a **new node** to the cluster. This distinction is essential for production operations.
