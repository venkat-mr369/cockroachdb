**3-node CockroachDB cluster**:

* **Node 1:** `10.10.10.11`
* **Node 2:** `10.10.10.12`
* **Node 3:** `10.10.10.13`

---

### Explanation of CockroachDB Certificate Files 

You have **5 certificate files** in `/var/lib/cockroach/certs/`.

Think of them as **identity cards and security keys** that allow CockroachDB nodes and clients to trust each other using **Mutual TLS (mTLS)**.

---

## 1. `ca.crt` (Certificate Authority Certificate)

### What is it?

The **Certificate Authority (CA)** certificate is the **root of trust** for the entire CockroachDB cluster.

It signs and validates every node certificate and client certificate.

### Who has it?

Every CockroachDB node uses the **same `ca.crt`**.

### Real-time Example

Think of it as the **government passport authority**.

Every passport (certificate) is trusted because it was issued by the same authority.

```text
ca.crt (SAME file on all 3 nodes)

        Certificate Authority
                 │
        ┌────────┼────────┐
        │        │        │
        ▼        ▼        ▼
Node1           Node2           Node3
10.10.10.11     10.10.10.12     10.10.10.13
     ✅              ✅              ✅
```

---

## 2. `node.crt` (Node Certificate)

### What is it?

The **identity certificate** of a CockroachDB node.

It tells other nodes:

> "I am Node1 running at 10.10.10.11."

### Who has it?

Each node has its **own unique node certificate**.

### Real-Life Example

Think of it as an **employee ID card**.

Every employee has a different ID card.

```text
node.crt (DIFFERENT on every node)

Node1
10.10.10.11
    │
    └── node.crt (Issued for Node1)

Node2
10.10.10.12
    │
    └── node.crt (Issued for Node2)

Node3
10.10.10.13
    │
    └── node.crt (Issued for Node3)
```

### Linux Permission

```text
-rw-r--r--
```

Public certificate (safe to read).

---

## 3. `node.key` (Node Private Key)

### What is it?

The **private key** corresponding to `node.crt`.

It proves that the node really owns its certificate.

### Who has it?

Each node has its **own private key**.

### Real-Life Example

Think of it as the **PIN number** for your employee ID card.

Only you should know it.

```text
node.key (DIFFERENT on every node)

Node1
10.10.10.11
    │
    └── node.key

Node2
10.10.10.12
    │
    └── node.key

Node3
10.10.10.13
    │
    └── node.key
```

### Linux Permission

```text
-rw-------
```

Only the owner should have permission.

---

## 4. `client.root.crt` (Root Client Certificate)

### What is it?

Identity certificate for the **root database administrator**.

It is used whenever you execute CockroachDB administrative commands.

### Who has it?

The **same copy** is available on all three nodes.

### Real-Life Example

Think of it as the **Master Administrator ID Card**.

You can administer the cluster from any node.

```text
client.root.crt (SAME on all nodes)

Node1
10.10.10.11

Node2
10.10.10.12

Node3
10.10.10.13

Used by:

cockroach sql
cockroach init
cockroach node status
cockroach node ls
```

### Linux Permission

```text
-rw-r--r--
```

Public certificate.

---

## 5. `client.root.key` (Root Client Private Key)

### What is it?

Private key used together with `client.root.crt`.

Without this file, the administrator cannot authenticate.

### Who has it?

The **same copy** exists on all nodes.

### Real-Life Example

Think of it as the **PIN number** for the Master Administrator ID card.

Only trusted administrators should have access.

### Linux Permission

```text
-rw-------
```

Private and confidential.

---

# How the Certificates Work Together

## Node-to-Node Communication

Suppose **Node2** wants to communicate with **Node1**.

```text
Node2 (10.10.10.12)
        │
        │ "Hello Node1"
        │
        │ Sends node.crt
        ▼
Node1 (10.10.10.11)

Step 1:
Node1 checks

"Was this certificate signed by ca.crt?"

          YES ✅

Step 2:
Node1 asks

"Prove you own this certificate."

Node2 signs the challenge using

node.key

Step 3:
Verification Successful

Node1 trusts Node2

Secure communication begins.
```

Exactly the same process happens when Node1 connects to Node2 or Node3.

This authentication is called:

> **Mutual TLS (mTLS)**

Both sides authenticate each other.

---

# Administrator Connection

When the DBA runs:

```bash
cockroach sql \
    --certs-dir=/var/lib/cockroach/certs \
    --host=10.10.10.11
```

CockroachDB performs the following verification.

```text
Administrator

client.root.crt
        │
        ▼

Node1

Step 1

Checks

Signed by ca.crt ?

YES ✅

Step 2

Prove ownership

Administrator uses

client.root.key

Step 3

Authentication Successful

Welcome root user.
```

---

# Certificate Distribution Across the Cluster

| File              | Node1 (10.10.10.11) | Node2 (10.10.10.12) | Node3 (10.10.10.13) | Same / Different |
| ----------------- | :-----------------: | :-----------------: | :-----------------: | ---------------- |
| `ca.crt`          |          ✅          |          ✅          |          ✅          | **Same**         |
| `node.crt`        |          ✅          |          ✅          |          ✅          | **Different**    |
| `node.key`        |          ✅          |          ✅          |          ✅          | **Different**    |
| `client.root.crt` |          ✅          |          ✅          |          ✅          | **Same**         |
| `client.root.key` |          ✅          |          ✅          |          ✅          | **Same**         |

---

# Security Rules

```text
Private Keys (.key)

node.key
client.root.key

Permission

chmod 600

Only the owner should have read/write access.

--------------------------------------------

Certificates (.crt)

ca.crt
node.crt
client.root.crt

Permission

chmod 644

Safe to read by everyone.

--------------------------------------------

Certificate Directory

/var/lib/cockroach/certs

Permission

chmod 700

Only the CockroachDB service account should access this directory.
```

---

# Important Note

Only **`ca.crt`**, **`client.root.crt`**, and **`client.root.key`** are identical across all nodes.

Each node must have its **own unique** `node.crt` and `node.key`, generated specifically for that node's hostname and IP addresses.

For example:

* **Node1 (10.10.10.11)** → `node.crt` contains `10.10.10.11`
* **Node2 (10.10.10.12)** → `node.crt` contains `10.10.10.12`
* **Node3 (10.10.10.13)** → `node.crt` contains `10.10.10.13`

This uniqueness is what allows CockroachDB to securely identify each node and establish trusted communication within the cluster.
