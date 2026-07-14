### Cleanup (Delete All AWS Resources)

> **Delete resources in reverse order of creation** to avoid dependency errors.

---

### Step 1: Delete CockroachDB Data (Optional)

Run on all three nodes.

Stop CockroachDB.

```bash
sudo systemctl stop cockroach
```

Disable the service.

```bash
sudo systemctl disable cockroach
```

---

### Step 2: Terminate EC2 Instances

Find the instances.

```bash
aws ec2 describe-instances --filters "Name=tag:Name,Values=crdb-node*" --query "Reservations[].Instances[].InstanceId" --output table
```

Terminate.

```bash
aws ec2 terminate-instances --instance-ids $NODE1_INSTANCE $NODE2_INSTANCE $NODE3_INSTANCE
```

Wait.

```bash
aws ec2 wait instance-terminated --instance-ids $NODE1_INSTANCE $NODE2_INSTANCE $NODE3_INSTANCE
```

---

### Step 3: Delete Key Pair

```bash
aws ec2 delete-key-pair --key-name crdb-key
```

Verify.

```bash
aws ec2 describe-key-pairs
```

---

### Step 4: Delete Security Group

```bash
aws ec2 delete-security-group --group-id $SG_ID
```

---

### Step 5: Disassociate Route Table

Find Associations.

```bash
aws ec2 describe-route-tables --route-table-ids $RT_ID
```

Delete each association except the **Main** association.

```bash
aws ec2 disassociate-route-table --association-id rtbassoc-09f9a485c9fcf8c1e
```

Repeat for all three subnet associations.
```
aws ec2 disassociate-route-table --association-id rtbassoc-0d5fba93703f6d454
aws ec2 disassociate-route-table --association-id rtbassoc-088bc0f470bee4fe0
```
---

### Step 6: Delete Route Table

```bash
aws ec2 delete-route-table --route-table-id $RT_ID
```

---

### Step 7: Delete Subnets

Subnet-1

```bash
aws ec2 delete-subnet --subnet-id $SUBNET1
```

Subnet-2

```bash
aws ec2 delete-subnet --subnet-id $SUBNET2
```

Subnet-3

```bash
aws ec2 delete-subnet --subnet-id $SUBNET3
```

---

### Step 8: Detach Internet Gateway

```bash
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
```

---

### Step 9: Delete Internet Gateway

```bash
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID
```

---

### Step 10: Delete VPC

```bash
aws ec2 delete-vpc --vpc-id $VPC_ID
```

---

## Verification

Verify VPC.

```bash
aws ec2 describe-vpcs
```

Verify EC2.

```bash
aws ec2 describe-instances
```

Verify Security Groups.

```bash
aws ec2 describe-security-groups
```

Verify Key Pairs.

```bash
aws ec2 describe-key-pairs
```

---

### Cleanup Order

```text
Stop CockroachDB (Optional)
        │
        ▼
Terminate EC2 Instances
        │
        ▼
Delete Key Pair
        │
        ▼
Delete Security Group
        │
        ▼
Disassociate Route Table
        │
        ▼
Delete Route Table
        │
        ▼
Delete Subnets
        │
        ▼
Detach Internet Gateway
        │
        ▼
Delete Internet Gateway
        │
        ▼
Delete VPC
```

### Lab Completed

You have now completed the full lifecycle of a CockroachDB cluster on AWS using the AWS CLI:

* ✅ Created AWS networking
* ✅ Launched EC2 instances
* ✅ Installed CockroachDB
* ✅ Initialized and verified the cluster
* ✅ Performed a basic failover test
* ✅ Cleaned up all AWS resources in the correct dependency order
