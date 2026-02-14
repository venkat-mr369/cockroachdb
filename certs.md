### CockroachDB Certificate Files Explained

You have 5 files in `/var/lib/cockroach/certs/`. Think of them like **ID cards and locks** for your cluster.

---

### 1. `ca.crt` (Certificate Authority Certificate)

**What:** The **boss certificate** — like a company stamp. It signs and verifies all other certificates.

**Who has it:** ALL 3 nodes (db1, db2, db3) get the **same copy**

**Real life example:** Like a university seal — every degree (node cert, client cert) has this seal to prove it's genuine.

```
ca.crt (SAME file on all 3 nodes)
  ├── db1 (10.0.1.220) ✅ has ca.crt
  ├── db2 (10.0.2.43)  ✅ has ca.crt
  └── db3 (10.0.3.241) ✅ has ca.crt
```

---

### 2. `node.crt` (Node Certificate)

**What:** This node's **identity card** — proves "I am db1 at 10.0.1.220"

**Who has it:** Each node has its **OWN unique** node.crt

**Real life example:** Like your employee ID badge — db1's badge says "I work at 10.0.1.220", db2's says "I work at 10.0.2.43"

```
node.crt (DIFFERENT on each node)
  ├── db1 → signed for 10.0.1.220
  ├── db2 → signed for 10.0.2.43    (different file!)
  └── db3 → signed for 10.0.3.241   (different file!)
```

**Permission:** `-rw-r--r--` (readable by all — this is public info)

---

### 3. `node.key` (Node Private Key)

**What:** This node's **secret password** — used to prove the node.crt is real

**Who has it:** Each node has its **OWN unique** node.key

**Real life example:** Like the PIN for your employee badge — only you know it

```
node.key (DIFFERENT on each node, KEEP SECRET)
  ├── db1 → private key for 10.0.1.220
  ├── db2 → private key for 10.0.2.43
  └── db3 → private key for 10.0.3.241
```

**Permission:** `-rw-------` (only owner can read — **secret!**)

---

### 4. `client.root.crt` (Root Client Certificate)

**What:** Identity card for the **root user** (admin). Used when you run `cockroach sql` or `cockroach init`

**Who has it:** ALL 3 nodes get the **same copy** (so you can run admin commands from any node)

**Real life example:** Like a master admin keycard that opens all doors

```
client.root.crt (SAME file on all 3 nodes)
  Used when you run:
  → cockroach sql --certs-dir=certs
  → cockroach init --certs-dir=certs
  → cockroach node status --certs-dir=certs
```

**Permission:** `-rw-r--r--` (readable by all — public info)

---

### 5. `client.root.key` (Root Client Private Key)

**What:** **Secret password** for the root client certificate

**Who has it:** ALL 3 nodes get the **same copy**

**Real life example:** The PIN for the master admin keycard

**Permission:** `-rw-------` (only owner can read — **secret!**)

---

## How They Work Together

```
When db2 connects to db1:

db2 says: "Hi db1, here's my node.crt"
db1 checks: "Is this signed by ca.crt?" ✅ Yes
db1 says: "Prove it — use your node.key"
db2 proves: (signs a challenge with node.key) ✅ Verified
db1 says: "Welcome db2!"

Same happens in reverse — db1 proves itself to db2.
This is called MUTUAL TLS (mTLS).
```

```
When you run cockroach sql:

You say: "Here's my client.root.crt"
Node checks: "Signed by ca.crt?" ✅ Yes
Node says: "Prove it"
You prove: (uses client.root.key) ✅ Verified
Node says: "Welcome root user!"
```

---

## What Each Node Should Have

| File | db1 (10.0.1.220) | db2 (10.0.2.43) | db3 (10.0.3.241) | Same or Different? |
|------|:-:|:-:|:-:|---|
| ca.crt | ✅ | ✅ | ✅ | **Same** on all |
| node.crt | ✅ | ✅ | ✅ | **Different** on each |
| node.key | ✅ | ✅ | ✅ | **Different** on each |
| client.root.crt | ✅ | ✅ | ✅ | **Same** on all |
| client.root.key | ✅ | ✅ | ✅ | **Same** on all |

---

## Security Rules

```
.key files  → KEEP SECRET  → chmod 600 (only owner reads)
.crt files  → PUBLIC info  → chmod 644 (anyone can read)
certs/ dir  → PROTECTED    → chmod 700 (only owner enters)
```

If permissions are wrong, CockroachDB will refuse to start with "permission denied" errors — that's by design for security.
