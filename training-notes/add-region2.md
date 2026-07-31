### Step 2: Create Networking in Region-B (AWS CLI)

First, configure the region:

```bash
aws configure
```

Or specify the region in each command:

```bash
export AWS_DEFAULT_REGION=ap-southeast-1
```

---

### 2.1 Create the VPC

```bash
aws ec2 create-vpc \
  --cidr-block 10.30.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=crdb-region2-vpc}]'
```

Save the **VpcId** (for example, `vpc-xxxxxxxx`).

---

### 2.2 Enable DNS Support

```bash
aws ec2 modify-vpc-attribute \
  --vpc-id <VPC-ID> \
  --enable-dns-support
```

```bash
aws ec2 modify-vpc-attribute \
  --vpc-id <VPC-ID> \
  --enable-dns-hostnames
```

---

### 2.3 Create Subnet for Node5

```bash
aws ec2 create-subnet \
  --vpc-id <VPC-ID> \
  --cidr-block 10.30.1.0/24 \
  --availability-zone ap-southeast-1a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=crdb-subnet-node5}]'
```

---

### 2.4 Create Subnet for Node6

```bash
aws ec2 create-subnet \
  --vpc-id <VPC-ID> \
  --cidr-block 10.30.2.0/24 \
  --availability-zone ap-southeast-1b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=crdb-subnet-node6}]'
```

Enable Auto Public IP Assignment 

Subnet:- crdb-subnet-node5

```
aws ec2 modify-subnet-attribute  --subnet-id subnet-0cb5a39590f921294 --map-public-ip-on-launch
```
Subnet:- crdb-subnet-node6

```
aws ec2 modify-subnet-attribute  --subnet-id subnet-09a5dfe1d2c26661d --map-public-ip-on-launch
```
Verify the Subnets, Expected:- True
```
aws ec2 describe-subnets \
    --region ap-southeast-1 \
    --subnet-ids subnet-0cb5a39590f921294 subnet-09a5dfe1d2c26661d \
    --query "Subnets[*].[SubnetId,MapPublicIpOnLaunch]" \
    --output table
```

---

### 2.5 Create Internet Gateway

```bash
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=crdb-igw}]'
```

Save the **InternetGatewayId**.

---

### 2.6 Attach the Internet Gateway

```bash
aws ec2 attach-internet-gateway  --internet-gateway-id <IGW-ID> --vpc-id <VPC-ID>
```

---

### 2.7 Create Route Table

```bash
aws ec2 create-route-table \
  --vpc-id <VPC-ID> \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=crdb-public-rt}]'
```

Save the **RouteTableId**.

---

### 2.8 Create Default Route

```bash
aws ec2 create-route \
  --route-table-id <ROUTE-TABLE-ID> \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id <IGW-ID>
```

---

### 2.9 Associate Route Table with Both Subnets

For Node5 subnet:

```bash
aws ec2 associate-route-table \
  --route-table-id <ROUTE-TABLE-ID> \
  --subnet-id <SUBNET1-ID>
```

For Node6 subnet:

```bash
aws ec2 associate-route-table \
  --route-table-id <ROUTE-TABLE-ID> \
  --subnet-id <SUBNET2-ID>
```

---


