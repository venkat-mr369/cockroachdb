#### The two VPCs (Region-A and Region-B) must be able to communicate.


**Region-A (Existing Cluster)**

* Region: `ap-south-1` (Mumbai)
* VPC CIDR: `10.10.0.0/16`
* VPC ID: `<VPC1-ID>`

**Region-B (New Region)**

* Region: `ap-southeast-1` (Singapore)
* VPC CIDR: `10.30.0.0/16`
* VPC ID: `<VPC2-ID>`

---

### Step 5.1 Create an Inter-Region VPC Peering Connection

Run from **Region-A (Mumbai)**:

```bash
aws ec2 create-vpc-peering-connection \
  --region ap-south-1 \
  --vpc-id <VPC1-ID> \
  --peer-vpc-id <VPC2-ID> \
  --peer-region ap-southeast-1
```

Expected output:

```text
VpcPeeringConnectionId: pcx-0857c1a3ac1c80948
```

Save the **VpcPeeringConnectionId**. & add a tag 

```
aws ec2 create-tags \
  --resources pcx-0857c1a3ac1c80948 \
  --tags Key=Name,Value=Mumbai-Singapore-Peering
```

---

### Step 5.2 Accept the Peering Connection

Run in **Region-B (Singapore)**:

```bash
aws ec2 accept-vpc-peering-connection \
  --region ap-southeast-1 \
  --vpc-peering-connection-id pcx-0857c1a3ac1c80948
```

---

### Step 5.3 Add a Route in Region-A

Find your Route Table ID:

```bash
aws ec2 describe-route-tables --region ap-south-1
```

Add the route:

```bash
aws ec2 create-route \
  --region ap-south-1 \
  --route-table-id <RTB1-ID> \
  --destination-cidr-block 10.30.0.0/16 \
  --vpc-peering-connection-id <PCX-ID>
```

---

### Step 5.4 Add a Route in Region-B

Find the Route Table:

```bash
aws ec2 describe-route-tables \
  --region ap-southeast-1
```

Add the route:

```bash
aws ec2 create-route \
  --region ap-southeast-1 \
  --route-table-id <RTB2-ID> \
  --destination-cidr-block 10.10.0.0/16 \
  --vpc-peering-connection-id <PCX-ID>
```

---

### Step 5.5 Verify the Peering Connection

```bash
aws ec2 describe-vpc-peering-connections \
  --region ap-south-1 \
  --vpc-peering-connection-ids pcx-0857c1a3ac1c80948
```

Expected state:

```text
Status: active
```

### Expected Result

* ✅ VPC peering status is **Active**
* ✅ Routes exist in both VPC route tables
* ✅ Nodes in both regions can reach each other over the private IP addresses


