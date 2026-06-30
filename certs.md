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

### Important Note

Only **`ca.crt`**, **`client.root.crt`**, and **`client.root.key`** are identical across all nodes.

Each node must have its **own unique** `node.crt` and `node.key`, generated specifically for that node's hostname and IP addresses.

For example:

* **Node1 (10.10.10.11)** → `node.crt` contains `10.10.10.11`
* **Node2 (10.10.10.12)** → `node.crt` contains `10.10.10.12`
* **Node3 (10.10.10.13)** → `node.crt` contains `10.10.10.13`

This uniqueness is what allows CockroachDB to securely identify each node and establish trusted communication within the cluster.

---

## "Why shouldn't we copy ca.key to all database servers? I created it here on Node1, so what's the reason?"

## Short Answer

For your **lab**, what you did is **correct**.

```text id="b6gcqz"
Node1

/var/lib/cockroach/my-safe-directory/

ca.key
```

There is **nothing wrong** with this because you're using Node1 to generate all the certificates.

The recommendation **not to copy `ca.key` to every node** applies to **production environments**.

---

# What is `ca.key`?

Think of `ca.key` as the **master signature**.

Anyone who has `ca.key` can create a certificate that every CockroachDB node will trust.

For example, with `ca.key` someone can run:

```bash id="tvuhxn"
cockroach cert create-node ...
```

or

```bash id="bw6yhk"
cockroach cert create-client hacker ...
```

Those certificates would be accepted because they were signed by the trusted CA.

---

# Why is that dangerous?

Imagine this cluster:

```text id="dzjlwm"
Node1
10.10.10.11

Node2
10.10.10.12

Node3
10.10.10.13
```

Suppose an attacker gains access to **Node2**.

If `ca.key` is stored there:

```text id="chclng"
Node2

ca.key
```

The attacker can generate:

```text id="jzjlwm"
fake-node.crt
fake-node.key
```

or

```text id="wxsdra"
client.admin.crt
client.admin.key
```

Since these certificates are signed by the trusted CA, **every node in the cluster will trust them**.

That is why `ca.key` is considered the most sensitive file.

---

# Real-Time Example

### Good Practice 🟢

```text id="vy4i6j"
Admin Machine

ca.key
ca.crt

        │
        ▼

Generate

node1.crt
node2.crt
node3.crt

client.root.crt

        │
        ▼

Copy ONLY the generated certificates

Node1
Node2
Node3
```

If Node2 is hacked:

```text id="6vrjlwm"
Node2

node.crt
node.key
ca.crt
```

The attacker **cannot** create new trusted certificates because `ca.key` is not there.

---

### Bad Practice 🔴

```text id="rzjlwm"
Node1
ca.key

Node2
ca.key

Node3
ca.key
```

If any one of these servers is compromised:

```text id="g1jlwm"
Attacker

↓

Steals ca.key

↓

Creates fake certificates

↓

Entire cluster trust is broken
```

---

# Then why did we create `ca.key` on Node1?

Because Node1 is acting as the **Certificate Authority** in your lab.

Your workflow is:

```text id="vjlwm"
Node1

Create CA

↓

ca.key

↓

Generate

node1.crt
node2.crt
node3.crt

↓

Copy certificates

↓

Done
```

After all certificates are generated:

**Production recommendation:**

```text id="ejlwm"
Delete or move

ca.key

to a secure backup location.
```

CockroachDB **does not need `ca.key` to run**.

It only needs:

```text id="djlwm"
ca.crt
node.crt
node.key
```

---

### What does CockroachDB actually use while running?

When the database starts:

```bash id="tjlwm"
cockroach start ...
```

CockroachDB reads:

```text id="cjlwm"
ca.crt
node.crt
node.key
```

It **never reads**:

```text id="ajlwvm"
ca.key
```

The `ca.key` file is only used when you execute commands such as:

```bash id="ojlwm"
cockroach cert create-node
```

or

```bash id="sjlwm"
cockroach cert create-client
```

---

### Lab vs Production

| Lab                                                      | Production                                                   |
| -------------------------------------------------------- | ------------------------------------------------------------ |
| 🟢 Keep `ca.key` on Node1 while generating certificates. | 🔴 Store `ca.key` on a secure administration machine or HSM. |
| 🟢 Generate all certificates from Node1.                 | 🟢 Generate all certificates from the CA machine.            |
| 🟢 Copy certificates to all nodes.                       | 🟢 Copy certificates to all nodes.                           |
| 🟢 Acceptable for learning.                              | 🟢 Recommended for enterprise deployments.                   |

---



> **Lab Environment**
>
> To simplify certificate management, we generate the CA and all certificates on **Node1**. Therefore, `ca.key` temporarily resides on Node1.
>
> **Production Environment**
>
> After generating all node and client certificates, `ca.key` should be removed from the CockroachDB nodes and stored securely on a dedicated Certificate Authority (CA) machine or a Hardware Security Module (HSM). This prevents an attacker who compromises a database node from issuing new trusted certificates.

This explains both **how to perform the lab** and **why production deployments handle the CA key differently**.

