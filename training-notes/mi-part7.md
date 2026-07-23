
Based on your existing AWS CLI labs, you **do not need to recreate the VPC, Security Group, or Route Table**. 
You only need to create **Subnet-4** and launch **crdb-node4**.

---

### AWS CLI Lab – Add CockroachDB Node4

## Prerequisites

You already have:

* ✅ VPC
* ✅ Internet Gateway
* ✅ Route Table
* ✅ Security Group (`sg_cockroach`)
* ✅ Key Pair (`crdb-key`)
* ✅ Node1
* ✅ Node2
* ✅ Node3

Available variables:

```bash
echo $VPC_ID
echo $RT_ID
echo $SG_ID
echo $AMI_ID
```

```
export VPC_ID=vpc-xxxxxxxxxxxxxxxxx
export RT_ID=rtb-xxxxxxxxxxxxxxxxx
export SG_ID=sg-xxxxxxxxxxxxxxxxx
export AMI_ID=ami-xxxxxxxxxxxxxxxxx
```

---

# Step 1: Create Public Subnet-4

Choose another Availability Zone. Since you already used:

* ap-south-1a
* ap-south-1b
* ap-south-1c

you can place Node4 in **ap-south-1a** again (AWS allows multiple subnets in the same AZ with different CIDRs).

```bash
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.10.4.0/24 \
  --availability-zone ap-south-1a
```

Save the Subnet ID:

```bash
export SUBNET4=subnet-xxxxxxxxxxxxxxxxx
```

Verify:

```bash
echo $SUBNET4
```

---

# Step 2: Tag the Subnet

```bash
aws ec2 create-tags \
  --resources $SUBNET4 \
  --tags Key=Name,Value=subnet-d
```

---

# Step 3: Enable Auto Public IP

```bash
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET4 \
  --map-public-ip-on-launch
```

Verify:

```bash
aws ec2 describe-subnets \
  --subnet-ids $SUBNET4 \
  --query "Subnets[].MapPublicIpOnLaunch"
```

Expected:

```text
true
```

---

# Step 4: Associate Route Table

```bash
aws ec2 associate-route-table \
  --subnet-id $SUBNET4 \
  --route-table-id $RT_ID
```

---

# Step 5: Verify Security Group

You already created:

```text
sg_cockroach
```

Verify:

```bash
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --output table
```

No changes are required because the new node will use the same security group.

---

# Step 6: Launch crdb-node4

```bash
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.small \
  --key-name crdb-key \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET4 \
  --private-ip-address 10.10.4.10 \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=crdb-node4}]'
```

Save the Instance ID:

```bash
export NODE4_INSTANCE=i-xxxxxxxxxxxxxxxxx
```

---

# Step 7: Wait Until Running

```bash
aws ec2 wait instance-running \
  --instance-ids $NODE4_INSTANCE
```

---

# Step 8: Verify the Instance

```bash
aws ec2 describe-instances \
  --instance-ids $NODE4_INSTANCE \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,AZ:Placement.AvailabilityZone}" \
  --output table
```

Example:

```text
------------------------------------------------------------
| Name        | State   | PrivateIP | PublicIP | AZ         |
------------------------------------------------------------
| crdb-node4  | running |10.10.4.10 |54.xx.xx.xx|ap-south-1a|
------------------------------------------------------------
```

---

# Step 9: List All Four Nodes

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=crdb-node*" \
  --query "Reservations[].Instances[].{Name:Tags[0].Value,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,State:State.Name}" \
  --output table
```

Expected:

```text
---------------------------------------------------------
| Name        | PrivateIP | PublicIP | State            |
---------------------------------------------------------
| crdb-node1  |10.10.1.10 | xx.xx.xx | running          |
| crdb-node2  |10.10.2.10 | xx.xx.xx | running          |
| crdb-node3  |10.10.3.10 | xx.xx.xx | running          |
| crdb-node4  |10.10.4.10 | xx.xx.xx | running          |
---------------------------------------------------------
```

---

# Step 10: SSH to Node4

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE4_PUBLIC_IP>
```

Verify:

```bash
hostname
hostname -I
```

---

# Step 11: Verify Connectivity

From **Node1**:

```bash
ping -c 5 10.10.4.10
```

From **Node4**:

```bash
ping -c 5 10.10.1.10
ping -c 5 10.10.2.10
ping -c 5 10.10.3.10
```

All pings should succeed.

---

## Result

At this stage, your AWS infrastructure will include:

* ✅ 1 VPC
* ✅ 4 Public Subnets

  * `subnet-a` → `10.10.1.0/24`
  * `subnet-b` → `10.10.2.0/24`
  * `subnet-c` → `10.10.3.0/24`
  * `subnet-d` → `10.10.4.0/24`
* ✅ 1 Route Table associated with all four subnets
* ✅ 1 Security Group (`sg_cockroach`)
* ✅ 4 Ubuntu 24.04 EC2 instances

  * `crdb-node1` → `10.10.1.10`
  * `crdb-node2` → `10.10.2.10`
  * `crdb-node3` → `10.10.3.10`
  * `crdb-node4` → `10.10.4.10`

The next step is to **install CockroachDB on `crdb-node4`, join it to the existing cluster, and verify automatic replica rebalancing**. That will complete the cluster expansion from 3 nodes to 4 nodes.
