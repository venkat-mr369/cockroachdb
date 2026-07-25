### Horizontal Scaling Adding Nodes into another region

### Step 1: Create a New VPC in Region-B

**Objective:** Create a new VPC in another AWS region where Node5 and Node6 will be deployed.

#### Existing Environment

* Region-A: `ap-south-1 (Mumbai)`

We will create the new region in:

* Region-B: `ap-southeast-1 (Singapore)` (you can choose another region if you prefer)

---

### 1. Switch to the New Region

1. Log in to the **AWS Management Console**.
2. In the top-right corner, click the **Region** dropdown.
3. Select **Singapore (ap-southeast-1)**.

---

### 2. Create a VPC

Navigate to:

**VPC → Your VPCs → Create VPC**

Configure:

| Setting             | Value              |
| ------------------- | ------------------ |
| Resources to create | VPC only           |
| Name                | `crdb-region2-vpc` |
| IPv4 CIDR           | `10.30.0.0/16`     |
| IPv6 CIDR           | None               |
| Tenancy             | Default            |

Click **Create VPC**.

---

### 3. Verify the VPC

You should see:

| Name               | CIDR           |
| ------------------ | -------------- |
| `crdb-region2-vpc` | `10.30.0.0/16` |

---

### Network Layout

```text
Region-A (Mumbai)
-----------------
VPC: 10.10.0.0/16
 ├── Node1
 ├── Node2
 ├── Node3
 └── Node4

Region-B (Singapore)
--------------------
VPC: 10.30.0.0/16
 ├── Node5 (Later)
 └── Node6 (Later)
```

### Lab Checkpoint

At the end of Step 1, you should have:

* ✅ Switched to the new AWS region
* ✅ Created a new VPC named `crdb-region2-vpc`
* ✅ Assigned the CIDR block `10.30.0.0/16`

In **Step 2**, we will create the networking inside this VPC:

* Public subnets
* Internet Gateway
* Route Table
* Security Group
* VPC Peering (to connect Region-A(mumbai) and Region-B(singapore) so the CockroachDB nodes can communicate).
