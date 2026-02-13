# AWS Infrastructure Setup — Paris Region (eu-west-3)
## CockroachDB 3-Node Cluster on Private Subnets

---

## Prerequisites

```bash
# Configure AWS CLI with Paris region
aws configure
# AWS Access Key ID: <your-key>
# AWS Secret Access Key: <your-secret>
# Default region name: eu-west-3
# Default output format: json
```

---

## Step 1: VPC Creation

```bash
# Create VPC with CIDR 10.0.0.0/16
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=cockroachdb-vpc}]' \
  --region eu-west-3

# Note the VpcId from output — e.g., vpc-0abc123def456789
# Export it for reuse
export VPC_ID="vpc-0abc123def456789"

# Enable DNS hostnames (required for internal resolution)
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-hostnames '{"Value": true}'

# Enable DNS support
aws ec2 modify-vpc-attribute \
  --vpc-id $VPC_ID \
  --enable-dns-support '{"Value": true}'
```

---

## Step 2: Create 3 Private Subnets + 1 Public Subnet

Paris has 3 AZs: `eu-west-3a`, `eu-west-3b`, `eu-west-3c`

### Private Subnets (for CockroachDB nodes)

```bash
# Private Subnet 1 — eu-west-3a (for db1)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.1.0/24 \
  --availability-zone eu-west-3a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cockroach-private-1a}]'

export PRIVATE_SUBNET_1="subnet-xxxxxxxxxxxxxxxxx"

# Private Subnet 2 — eu-west-3b (for db2)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.2.0/24 \
  --availability-zone eu-west-3b \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cockroach-private-2b}]'

export PRIVATE_SUBNET_2="subnet-xxxxxxxxxxxxxxxxx"

# Private Subnet 3 — eu-west-3c (for db3)
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.3.0/24 \
  --availability-zone eu-west-3c \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cockroach-private-3c}]'

export PRIVATE_SUBNET_3="subnet-xxxxxxxxxxxxxxxxx"
```

### Public Subnet (for NAT Gateway + Bastion/Jump host)

```bash
# Public Subnet — eu-west-3a
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.0.100.0/24 \
  --availability-zone eu-west-3a \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=cockroach-public-1a}]'

export PUBLIC_SUBNET="subnet-xxxxxxxxxxxxxxxxx"

# Enable auto-assign public IP on public subnet
aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET \
  --map-public-ip-on-launch
```

---

## Step 3: Create and Attach Internet Gateway

```bash
# Create Internet Gateway
aws ec2 create-internet-gateway \
  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=cockroach-igw}]'

export IGW_ID="igw-xxxxxxxxxxxxxxxxx"

# Attach IGW to VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id $VPC_ID
```

---

## Step 4: Create Route Tables and Update Routes

### Public Route Table (for public subnet)

```bash
# Create public route table
aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cockroach-public-rt}]'

export PUBLIC_RT="rtb-xxxxxxxxxxxxxxxxx"

# Add route to Internet Gateway (0.0.0.0/0 → IGW)
aws ec2 create-route \
  --route-table-id $PUBLIC_RT \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID

# Associate public subnet with public route table
aws ec2 associate-route-table \
  --route-table-id $PUBLIC_RT \
  --subnet-id $PUBLIC_SUBNET
```

### Private Route Table (for private subnets)

```bash
# Create private route table
aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=cockroach-private-rt}]'

export PRIVATE_RT="rtb-xxxxxxxxxxxxxxxxx"

# Associate all 3 private subnets with private route table
aws ec2 associate-route-table \
  --route-table-id $PRIVATE_RT \
  --subnet-id $PRIVATE_SUBNET_1

aws ec2 associate-route-table \
  --route-table-id $PRIVATE_RT \
  --subnet-id $PRIVATE_SUBNET_2

aws ec2 associate-route-table \
  --route-table-id $PRIVATE_RT \
  --subnet-id $PRIVATE_SUBNET_3
```

---

## Step 5: Create NAT Gateway with Elastic IP

```bash
# Allocate Elastic IP for NAT Gateway
aws ec2 allocate-address \
  --domain vpc \
  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=cockroach-nat-eip}]'

export EIP_ALLOC="eipalloc-xxxxxxxxxxxxxxxxx"

# Create NAT Gateway in PUBLIC subnet
aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET \
  --allocation-id $EIP_ALLOC \
  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=cockroach-nat-gw}]'

export NAT_GW="nat-xxxxxxxxxxxxxxxxx"

# Wait for NAT Gateway to become available (takes 1-2 minutes)
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW
echo "NAT Gateway is ready!"

# Add route in PRIVATE route table: 0.0.0.0/0 → NAT Gateway
aws ec2 create-route \
  --route-table-id $PRIVATE_RT \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW
```

---

## Step 6: Create Security Groups

### CockroachDB Security Group (private instances)

```bash
# Create security group for CockroachDB nodes
aws ec2 create-security-group \
  --group-name cockroach-sg \
  --description "CockroachDB cluster security group" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=cockroach-sg}]'

export CRDB_SG="sg-xxxxxxxxxxxxxxxxx"

# Allow inter-node communication (port 26257) within VPC
aws ec2 authorize-security-group-ingress \
  --group-id $CRDB_SG \
  --protocol tcp \
  --port 26257 \
  --cidr 10.0.0.0/16

# Allow Admin UI (port 8080) within VPC
aws ec2 authorize-security-group-ingress \
  --group-id $CRDB_SG \
  --protocol tcp \
  --port 8080 \
  --cidr 10.0.0.0/16

# Allow SSH from within VPC (for bastion access)
aws ec2 authorize-security-group-ingress \
  --group-id $CRDB_SG \
  --protocol tcp \
  --port 22 \
  --cidr 10.0.0.0/16
```

### Bastion Security Group (public instance for SSH jump)

```bash
aws ec2 create-security-group \
  --group-name bastion-sg \
  --description "Bastion host security group" \
  --vpc-id $VPC_ID \
  --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=bastion-sg}]'

export BASTION_SG="sg-xxxxxxxxxxxxxxxxx"

# Allow SSH from your IP (replace with your public IP)
aws ec2 authorize-security-group-ingress \
  --group-id $BASTION_SG \
  --protocol tcp \
  --port 22 \
  --cidr <YOUR_PUBLIC_IP>/32
```

---

## Step 7: Create Key Pair

```bash
aws ec2 create-key-pair \
  --key-name cockroach-key \
  --key-type rsa \
  --query 'KeyMaterial' \
  --output text > cockroach-key.pem

chmod 400 cockroach-key.pem
```

---

## Step 8: Launch EC2 Instances

### Find latest Ubuntu 24.04 AMI in Paris

```bash
export AMI_ID=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region eu-west-3)

echo "AMI: $AMI_ID"
```

### Launch 3 CockroachDB Nodes (Private Subnets)

```bash
# db1 — Private Subnet 1 (eu-west-3a) — IP: 10.0.1.10
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name cockroach-key \
  --subnet-id $PRIVATE_SUBNET_1 \
  --private-ip-address 10.0.1.10 \
  --security-group-ids $CRDB_SG \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cockroach-db1}]' \
  --region eu-west-3

export DB1_INSTANCE="i-xxxxxxxxxxxxxxxxx"

# db2 — Private Subnet 2 (eu-west-3b) — IP: 10.0.2.10
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name cockroach-key \
  --subnet-id $PRIVATE_SUBNET_2 \
  --private-ip-address 10.0.2.10 \
  --security-group-ids $CRDB_SG \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cockroach-db2}]' \
  --region eu-west-3

export DB2_INSTANCE="i-xxxxxxxxxxxxxxxxx"

# db3 — Private Subnet 3 (eu-west-3c) — IP: 10.0.3.10
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.medium \
  --key-name cockroach-key \
  --subnet-id $PRIVATE_SUBNET_3 \
  --private-ip-address 10.0.3.10 \
  --security-group-ids $CRDB_SG \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cockroach-db3}]' \
  --region eu-west-3

export DB3_INSTANCE="i-xxxxxxxxxxxxxxxxx"
```

### Launch Bastion Host (Public Subnet)

```bash
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.micro \
  --key-name cockroach-key \
  --subnet-id $PUBLIC_SUBNET \
  --security-group-ids $BASTION_SG \
  --associate-public-ip-address \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=cockroach-bastion}]' \
  --region eu-west-3

export BASTION_INSTANCE="i-xxxxxxxxxxxxxxxxx"
```

---

## Step 9: Wait for Instances and Get IPs

```bash
# Wait for all instances to be running
aws ec2 wait instance-running \
  --instance-ids $DB1_INSTANCE $DB2_INSTANCE $DB3_INSTANCE $BASTION_INSTANCE

# Get Bastion public IP
export BASTION_IP=$(aws ec2 describe-instances \
  --instance-ids $BASTION_INSTANCE \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

echo "Bastion Public IP: $BASTION_IP"

# Verify private IPs
aws ec2 describe-instances \
  --instance-ids $DB1_INSTANCE $DB2_INSTANCE $DB3_INSTANCE \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],PrivateIpAddress]' \
  --output table
```

---

## Step 10: Test — SSH into Private Instance and curl google.com

### SSH into Bastion, then hop to a private node

```bash
# Option A: SSH Agent Forwarding (recommended)
eval "$(ssh-agent -s)"
ssh-add cockroach-key.pem

# SSH into bastion with agent forwarding
ssh -A -i cockroach-key.pem ubuntu@$BASTION_IP

# From bastion, SSH into db1 (private subnet)
ssh ubuntu@10.0.1.10
```

### Test internet access via NAT Gateway

```bash
# On the private EC2 instance (db1):

# Quick test — should return "200"
curl -s -o /dev/null -w "%{http_code}" https://www.google.com

# Full test — should return Google HTML
curl https://www.google.com

# Ping test
ping -c 3 google.com

# Headers only
curl -I https://www.google.com
```

If you get `200` or see Google HTML, your NAT Gateway is working correctly.

---

## Architecture Diagram

```
                    INTERNET
                       │
                  ┌────┴────┐
                  │   IGW   │
                  └────┬────┘
                       │
              ┌────────┴─────────┐
              │  cockroachdb-vpc  │
              │   10.0.0.0/16    │
              └────────┬─────────┘
                       │
         ┌─────────────┼──────────────┐
         │             │              │
   ┌─────┴──────┐     │     ┌────────┴────────┐
   │  Public     │     │     │ Private Route   │
   │  Subnet     │     │     │ Table           │
   │ 10.0.100.0  │     │     │ 0.0.0.0/0 →    │
   │   /24       │     │     │    NAT GW       │
   │             │     │     └────────┬────────┘
   │ • Bastion   │     │              │
   │ • NAT GW    │     │     ┌────────┼────────┐
   │   (+ EIP)   │     │     │        │        │
   └─────────────┘     │     │        │        │
                       │     │        │        │
                 ┌─────┴──┐ ┌┴────────┴┐ ┌────┴─────┐
                 │Private │ │Private   │ │Private   │
                 │Sub 1   │ │Sub 2     │ │Sub 3     │
                 │10.0.1.0│ │10.0.2.0  │ │10.0.3.0  │
                 │  /24   │ │  /24     │ │  /24     │
                 │        │ │          │ │          │
                 │ db1    │ │ db2      │ │ db3      │
                 │.1.10   │ │.2.10     │ │.3.10     │
                 └────────┘ └──────────┘ └──────────┘
                   3a          3b           3c
```

---

## Cleanup (when done)

```bash
# Terminate instances
aws ec2 terminate-instances \
  --instance-ids $DB1_INSTANCE $DB2_INSTANCE $DB3_INSTANCE $BASTION_INSTANCE
aws ec2 wait instance-terminated \
  --instance-ids $DB1_INSTANCE $DB2_INSTANCE $DB3_INSTANCE $BASTION_INSTANCE

# Delete NAT Gateway (wait ~60s for deletion)
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_GW
sleep 60

# Release Elastic IP
aws ec2 release-address --allocation-id $EIP_ALLOC

# Detach and delete IGW
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

# Delete subnets
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_1
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_2
aws ec2 delete-subnet --subnet-id $PRIVATE_SUBNET_3
aws ec2 delete-subnet --subnet-id $PUBLIC_SUBNET

# Delete route tables (disassociate first if needed)
aws ec2 delete-route-table --route-table-id $PUBLIC_RT
aws ec2 delete-route-table --route-table-id $PRIVATE_RT

# Delete security groups
aws ec2 delete-security-group --group-id $CRDB_SG
aws ec2 delete-security-group --group-id $BASTION_SG

# Delete VPC
aws ec2 delete-vpc --vpc-id $VPC_ID

# Delete key pair
aws ec2 delete-key-pair --key-name cockroach-key
rm cockroach-key.pem
```
