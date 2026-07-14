### AWS CLI Lab – Part 1

### Create VPC, Internet Gateway, Route Table

We'll use these values throughout the lab.

```text
Region      : ap-south-1 (Mumbai)

Project     : CockroachDB Lab

VPC Name    : vpc-crdb

CIDR        : 10.10.0.0/16
```

---

### Step 1: Configure AWS CLI

Verify AWS CLI is configured.

```bash
aws configure
```

Verify the account.

```bash
aws sts get-caller-identity
```

Verify the region.

```bash
aws configure get region
```

Expected

```text
ap-south-1
```

---

### Step 2: Create VPC

```bash
aws ec2 create-vpc --cidr-block 10.10.0.0/16 --region ap-south-1
```

Example Output

```text
VpcId

vpc-01e24978206b6c8b0
```

Save the VPC ID.

```bash
export VPC_ID=vpc-01e24978206b6c8b0
```

Windows PowerShell

```powershell
$VPC_ID="vpc-xxxxxxxxxxxxxxxxx"
```

---

### Step 3: Name the VPC

```bash
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=vpc-crdb
```

Verify

```bash
aws ec2 describe-vpcs --vpc-ids $VPC_ID
```

---

### Step 4: Enable DNS Hostnames

```bash
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
```

Enable DNS Support

```bash
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
```

Verify

```bash
aws ec2 describe-vpc-attribute --vpc-id $VPC_ID --attribute enableDnsHostnames
```

---

### Step 5: Create Internet Gateway

```bash
aws ec2 create-internet-gateway
```

Example Output

```text
InternetGatewayId

igw-03d31307394879ae5
```

Save it.

```bash
export IGW_ID=igw-03d31307394879ae5
```

---

### Step 6: Name Internet Gateway

```bash
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=igw-crdb
```

---

### Step 7: Attach Internet Gateway to VPC

```bash
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
```

Verify

```bash
aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID
```

---

### Step 8: Create Public Route Table

```bash
aws ec2 create-route-table --vpc-id $VPC_ID
```

Example

```text
RouteTableId

rtb-08f7b80c6813fd2c9
```

Save it.

```bash
export RT_ID=rtb-08f7b80c6813fd2c9
```

---

### Step 9: Name Route Table

```bash
aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=rt-public
```

---

### Step 10: Create Internet Route

```bash
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
```

```
Expected
true
```

Verify

```bash
aws ec2 describe-route-tables --route-table-ids $RT_ID
```

Expected Route

```text
DestinationCidrBlock

0.0.0.0/0

Target

Internet Gateway
```

---

### Verify Part 1

Run:

```bash
aws ec2 describe-vpcs --vpc-ids $VPC_ID
```

```bash
aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID
```

```bash
aws ec2 describe-route-tables --route-table-ids $RT_ID
```

### At the end of Part 1, you will have:

* ✅ 1 VPC (`vpc-crdb`)
* ✅ DNS Hostnames Enabled
* ✅ DNS Support Enabled
* ✅ 1 Internet Gateway (`igw-crdb`)
* ✅ Internet Gateway attached to the VPC
* ✅ 1 Public Route Table (`rt-public`)
* ✅ Default route (`0.0.0.0/0`) pointing to the Internet Gateway

