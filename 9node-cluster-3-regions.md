Complete multi-region CockroachDB 9-node cluster guide. you can find end-to-end:

**3 Regions fully set up with AWS CLI:**
- 🇫🇷 Paris (eu-west-3) — Nodes 1-3
- 🇺🇸 US-East (us-east-1) — Nodes 4-6
- 🇮🇳 Mumbai (ap-south-1) — Nodes 7-9

**For each region:** VPC → 3 private subnets + 1 public → IGW → route tables → NAT Gateway → security groups (with cross-region CIDR rules for ports 26257/8080) → key pair → 3 DB instances + 1 bastion

**Cross-region connectivity:** All 3 VPC Peering connections (Paris↔US, US↔Mumbai, Paris↔Mumbai) with route updates

**CockroachDB setup:** Binary install, certificate generation for all 9 nodes, start commands with `--locality` flags for each node, cluster init, multi-region database creation with `SURVIVE REGION FAILURE`

**Plus:** Complete cleanup commands, resource count table, and estimated monthly cost (~$443/mo)

--------
### Multi-Region CockroachDB 9-Node Cluster — AWS CLI Complete Steps

> Deploy a production-grade CockroachDB cluster across **3 AWS regions** (Paris, N. Virginia, Mumbai) with **3 nodes per region** (9 nodes total), VPC Peering, and full network setup — all using AWS CLI.

---

### Architecture Overview

```
                        GLOBAL COCKROACHDB CLUSTER (9 Nodes)
  ┌─────────────────────────────────────────────────────────────────────────┐
  │                                                                         │
  │    PARIS (eu-west-3)       US-EAST (us-east-1)      MUMBAI (ap-south-1) │
  │    ┌───────────────┐       ┌───────────────┐        ┌───────────────┐   │
  │    │  VPC          │       │  VPC          │        │  VPC          │   │
  │    │  10.0.0.0/16  │◄─────►│  10.1.0.0/16  │◄──────►│  10.2.0.0/16  │   │
  │    │               │  VPC  │               │  VPC   │               │   │
  │    │ ┌───┐┌───┐┌───┐│Peer  │ ┌───┐┌───┐┌───┐│ Peer  │ ┌───┐┌───┐┌───┐│  │
  │    │ │N1 ││N2 ││N3 ││──────│ │N4 ││N5 ││N6 ││───────│ │N7 ││N8 ││N9 ││  │
  │    │ └───┘└───┘└───┘│      │ └───┘└───┘└───┘│       │ └───┘└───┘└───┘│  │
  │    │  AZ-a  AZ-b AZ-c│     │ AZ-a  AZ-b AZ-c│      │ AZ-a  AZ-b AZ-c│   │
  │    └───────────────┘       └───────────────┘        └───────────────┘   │
  │         │                        │                        │             │
  │         └────────────────────────┼────────────────────────┘             │
  │                     VPC Peering (Paris↔Mumbai)                          │
  └─────────────────────────────────────────────────────────────────────────┘
```

---

## IP Address Plan

| Region | VPC CIDR | Subnet 1 (AZ-a) | Subnet 2 (AZ-b) | Subnet 3 (AZ-c) | Public Subnet | Node IPs |
|--------|----------|-----------------|-----------------|-----------------|---------------|----------|
| **Paris** (eu-west-3) | 10.0.0.0/16 | 10.0.1.0/24 | 10.0.2.0/24 | 10.0.3.0/24 | 10.0.100.0/24 | .10 each |
| **US-East** (us-east-1) | 10.1.0.0/16 | 10.1.1.0/24 | 10.1.2.0/24 | 10.1.3.0/24 | 10.1.100.0/24 | .10 each |
| **Mumbai** (ap-south-1) | 10.2.0.0/16 | 10.2.1.0/24 | 10.2.2.0/24 | 10.2.3.0/24 | 10.2.100.0/24 | .10 each |

### All 9 Node Private IPs

| Node | Region | Subnet | Private IP |
|------|--------|--------|------------|
| Node 1 | Paris | 10.0.1.0/24 (AZ-a) | **10.0.1.10** |
| Node 2 | Paris | 10.0.2.0/24 (AZ-b) | **10.0.2.10** |
| Node 3 | Paris | 10.0.3.0/24 (AZ-c) | **10.0.3.10** |
| Node 4 | US-East | 10.1.1.0/24 (AZ-a) | **10.1.1.10** |
| Node 5 | US-East | 10.1.2.0/24 (AZ-b) | **10.1.2.10** |
| Node 6 | US-East | 10.1.3.0/24 (AZ-c) | **10.1.3.10** |
| Node 7 | Mumbai | 10.2.1.0/24 (AZ-a) | **10.2.1.10** |
| Node 8 | Mumbai | 10.2.2.0/24 (AZ-b) | **10.2.2.10** |
| Node 9 | Mumbai | 10.2.3.0/24 (AZ-c) | **10.2.3.10** |

### Ports Required

| Port | Purpose |
|------|---------|
| **26257** | CockroachDB SQL + inter-node communication |
| **8080** | CockroachDB Admin UI |
| **22** | SSH access |

---

## REGION 1: PARIS (eu-west-3)

### Step 1.1: Create VPC

```bash
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region eu-west-3
```
> 📋 Copy `VpcId` → replace `vpc-paris` everywhere below

```bash
aws ec2 create-tags --resources vpc-paris \
  --tags Key=Name,Value=crdb-vpc-paris \
  --region eu-west-3

aws ec2 modify-vpc-attribute --vpc-id vpc-paris \
  --enable-dns-hostnames \
  --region eu-west-3

aws ec2 modify-vpc-attribute --vpc-id vpc-paris \
  --enable-dns-support \
  --region eu-west-3
```

### Step 1.2: Create 3 Private Subnets + 1 Public Subnet

```bash
# Private Subnet 1 — AZ-a
aws ec2 create-subnet \
  --vpc-id vpc-paris \
  --cidr-block 10.0.1.0/24 \
  --availability-zone eu-west-3a \
  --region eu-west-3
```
> 📋 Copy `SubnetId` → replace `paris-sub1`
```bash
aws ec2 create-tags --resources paris-sub1 \
  --tags Key=Name,Value=crdb-paris-private-1a \
  --region eu-west-3
```

```bash
# Private Subnet 2 — AZ-b
aws ec2 create-subnet \
  --vpc-id vpc-paris \
  --cidr-block 10.0.2.0/24 \
  --availability-zone eu-west-3b \
  --region eu-west-3
```
> 📋 Copy `SubnetId` → replace `paris-sub2`
```bash
aws ec2 create-tags --resources paris-sub2 \
  --tags Key=Name,Value=crdb-paris-private-2b \
  --region eu-west-3
```

```bash
# Private Subnet 3 — AZ-c
aws ec2 create-subnet \
  --vpc-id vpc-paris \
  --cidr-block 10.0.3.0/24 \
  --availability-zone eu-west-3c \
  --region eu-west-3
```
> 📋 Copy `SubnetId` → replace `paris-sub3`
```bash
aws ec2 create-tags --resources paris-sub3 \
  --tags Key=Name,Value=crdb-paris-private-3c \
  --region eu-west-3
```

```bash
# Public Subnet — AZ-a (for Bastion + NAT Gateway)
aws ec2 create-subnet \
  --vpc-id vpc-paris \
  --cidr-block 10.0.100.0/24 \
  --availability-zone eu-west-3a \
  --region eu-west-3
```
> 📋 Copy `SubnetId` → replace `paris-sub-pub`
```bash
aws ec2 create-tags --resources paris-sub-pub \
  --tags Key=Name,Value=crdb-paris-public \
  --region eu-west-3

aws ec2 modify-subnet-attribute \
  --subnet-id paris-sub-pub \
  --map-public-ip-on-launch \
  --region eu-west-3
```

### Step 1.3: Internet Gateway

```bash
aws ec2 create-internet-gateway --region eu-west-3
```
> 📋 Copy `InternetGatewayId` → replace `igw-paris`
```bash
aws ec2 create-tags --resources igw-paris \
  --tags Key=Name,Value=crdb-igw-paris \
  --region eu-west-3

aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-paris \
  --vpc-id vpc-paris \
  --region eu-west-3
```

### Step 1.4: Route Tables

```bash
# Public Route Table
aws ec2 create-route-table --vpc-id vpc-paris --region eu-west-3
```
> 📋 Copy `RouteTableId` → replace `pub-rt-paris`
```bash
aws ec2 create-tags --resources pub-rt-paris \
  --tags Key=Name,Value=crdb-public-rt-paris \
  --region eu-west-3

aws ec2 create-route \
  --route-table-id pub-rt-paris \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id igw-paris \
  --region eu-west-3

aws ec2 associate-route-table \
  --route-table-id pub-rt-paris \
  --subnet-id paris-sub-pub \
  --region eu-west-3
```

```bash
# Private Route Table
aws ec2 create-route-table --vpc-id vpc-paris --region eu-west-3
```
> 📋 Copy `RouteTableId` → replace `priv-rt-paris`
```bash
aws ec2 create-tags --resources priv-rt-paris \
  --tags Key=Name,Value=crdb-private-rt-paris \
  --region eu-west-3

aws ec2 associate-route-table \
  --route-table-id priv-rt-paris \
  --subnet-id paris-sub1 \
  --region eu-west-3

aws ec2 associate-route-table \
  --route-table-id priv-rt-paris \
  --subnet-id paris-sub2 \
  --region eu-west-3

aws ec2 associate-route-table \
  --route-table-id priv-rt-paris \
  --subnet-id paris-sub3 \
  --region eu-west-3
```

### Step 1.5: NAT Gateway

```bash
aws ec2 allocate-address --domain vpc --region eu-west-3
```
> 📋 Copy `AllocationId` → replace `eip-paris`
```bash
aws ec2 create-tags --resources eip-paris \
  --tags Key=Name,Value=crdb-eip-paris \
  --region eu-west-3

aws ec2 create-nat-gateway \
  --subnet-id paris-sub-pub \
  --allocation-id eip-paris \
  --region eu-west-3
```
> 📋 Copy `NatGatewayId` → replace `nat-paris`
```bash
aws ec2 create-tags --resources nat-paris \
  --tags Key=Name,Value=crdb-nat-paris \
  --region eu-west-3

# Wait for NAT Gateway to become available (takes ~2 minutes)
aws ec2 wait nat-gateway-available \
  --nat-gateway-ids nat-paris \
  --region eu-west-3

# Add default route via NAT for private subnets
aws ec2 create-route \
  --route-table-id priv-rt-paris \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id nat-paris \
  --region eu-west-3
```

### Step 1.6: Security Groups

```bash
# CockroachDB Nodes Security Group
aws ec2 create-security-group \
  --group-name crdb-sg-paris \
  --description "CockroachDB nodes Paris" \
  --vpc-id vpc-paris \
  --region eu-west-3
```
> 📋 Copy `GroupId` → replace `crdb-sg-paris`
```bash
aws ec2 create-tags --resources crdb-sg-paris \
  --tags Key=Name,Value=crdb-sg-paris \
  --region eu-west-3

# Allow CockroachDB SQL (26257) from all 3 VPC CIDRs
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris \
  --protocol tcp --port 26257 --cidr 10.0.0.0/16 --region eu-west-3
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris \
  --protocol tcp --port 26257 --cidr 10.1.0.0/16 --region eu-west-3
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris \
  --protocol tcp --port 26257 --cidr 10.2.0.0/16 --region eu-west-3

# Allow Admin UI (8080) from all 3 VPC CIDRs
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris \
  --protocol tcp --port 8080 --cidr 10.0.0.0/16 --region eu-west-3
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris \
  --protocol tcp --port 8080 --cidr 10.1.0.0/16 --region eu-west-3
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris \
  --protocol tcp --port 8080 --cidr 10.2.0.0/16 --region eu-west-3

# Allow SSH from within VPC
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris \
  --protocol tcp --port 22 --cidr 10.0.0.0/16 --region eu-west-3
```

```bash
# Bastion Security Group
aws ec2 create-security-group \
  --group-name bastion-sg-paris \
  --description "Bastion SSH Paris" \
  --vpc-id vpc-paris \
  --region eu-west-3
```
> 📋 Copy `GroupId` → replace `bastion-sg-paris`
```bash
aws ec2 create-tags --resources bastion-sg-paris \
  --tags Key=Name,Value=crdb-bastion-sg-paris \
  --region eu-west-3

# ⚠️ Replace YOUR_IP with your actual public IP
aws ec2 authorize-security-group-ingress --group-id bastion-sg-paris \
  --protocol tcp --port 22 --cidr YOUR_IP/32 --region eu-west-3
```

### Step 1.7: Key Pair

```bash
aws ec2 create-key-pair \
  --key-name crdb-key-paris \
  --query 'KeyMaterial' \
  --output text \
  --region eu-west-3 > crdb-key-paris.pem

chmod 400 crdb-key-paris.pem
```

### Step 1.8: Get AMI & Launch Instances

```bash
# Get latest Ubuntu 24.04 AMI for Paris region
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
             "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text \
  --region eu-west-3
```
> 📋 Copy AMI ID → replace `ami-paris`

```bash
# Node 1 — Paris AZ-a (10.0.1.10)
aws ec2 run-instances \
  --image-id ami-paris \
  --instance-type t3.medium \
  --key-name crdb-key-paris \
  --subnet-id paris-sub1 \
  --private-ip-address 10.0.1.10 \
  --security-group-ids crdb-sg-paris \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region eu-west-3
```
> 📋 Copy `InstanceId` → replace `paris-node1`
```bash
aws ec2 create-tags --resources paris-node1 \
  --tags Key=Name,Value=crdb-paris-node1 \
  --region eu-west-3
```

```bash
# Node 2 — Paris AZ-b (10.0.2.10)
aws ec2 run-instances \
  --image-id ami-paris \
  --instance-type t3.medium \
  --key-name crdb-key-paris \
  --subnet-id paris-sub2 \
  --private-ip-address 10.0.2.10 \
  --security-group-ids crdb-sg-paris \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region eu-west-3
```
> 📋 Copy `InstanceId` → replace `paris-node2`
```bash
aws ec2 create-tags --resources paris-node2 \
  --tags Key=Name,Value=crdb-paris-node2 \
  --region eu-west-3
```

```bash
# Node 3 — Paris AZ-c (10.0.3.10)
aws ec2 run-instances \
  --image-id ami-paris \
  --instance-type t3.medium \
  --key-name crdb-key-paris \
  --subnet-id paris-sub3 \
  --private-ip-address 10.0.3.10 \
  --security-group-ids crdb-sg-paris \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region eu-west-3
```
> 📋 Copy `InstanceId` → replace `paris-node3`
```bash
aws ec2 create-tags --resources paris-node3 \
  --tags Key=Name,Value=crdb-paris-node3 \
  --region eu-west-3
```

```bash
# Bastion Host — Paris Public Subnet
aws ec2 run-instances \
  --image-id ami-paris \
  --instance-type t3.micro \
  --key-name crdb-key-paris \
  --subnet-id paris-sub-pub \
  --security-group-ids bastion-sg-paris \
  --associate-public-ip-address \
  --region eu-west-3
```
> 📋 Copy `InstanceId` → replace `paris-bastion`
```bash
aws ec2 create-tags --resources paris-bastion \
  --tags Key=Name,Value=crdb-bastion-paris \
  --region eu-west-3
```

### Step 1.9: Get Bastion Public IP

```bash
aws ec2 describe-instances \
  --instance-ids paris-bastion \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text \
  --region eu-west-3
```

### Step 1.10: Test Internet from Private Node

```bash
eval "$(ssh-agent -s)"
ssh-add crdb-key-paris.pem

# SSH into Bastion
ssh -A -i crdb-key-paris.pem ubuntu@BASTION_PUBLIC_IP

# From Bastion → SSH into Node 1
ssh ubuntu@10.0.1.10

# Test internet connectivity (via NAT Gateway)
curl -s https://www.google.com | head -5
ping -c 3 google.com
```

---

## REGION 2: US-EAST (us-east-1)

> **Same steps as Paris, just change the variables.** Every command below is ready to copy-paste.

### Step 2.1: Create VPC

```bash
aws ec2 create-vpc \
  --cidr-block 10.1.0.0/16 \
  --region us-east-1
```
> 📋 Copy `VpcId` → replace `vpc-useast`
```bash
aws ec2 create-tags --resources vpc-useast \
  --tags Key=Name,Value=crdb-vpc-useast \
  --region us-east-1

aws ec2 modify-vpc-attribute --vpc-id vpc-useast \
  --enable-dns-hostnames --region us-east-1

aws ec2 modify-vpc-attribute --vpc-id vpc-useast \
  --enable-dns-support --region us-east-1
```

### Step 2.2: Create Subnets

```bash
# Private Subnet 1 — AZ-a
aws ec2 create-subnet --vpc-id vpc-useast \
  --cidr-block 10.1.1.0/24 --availability-zone us-east-1a --region us-east-1
```
> 📋 Copy → replace `useast-sub1`
```bash
aws ec2 create-tags --resources useast-sub1 \
  --tags Key=Name,Value=crdb-useast-private-1a --region us-east-1
```

```bash
# Private Subnet 2 — AZ-b
aws ec2 create-subnet --vpc-id vpc-useast \
  --cidr-block 10.1.2.0/24 --availability-zone us-east-1b --region us-east-1
```
> 📋 Copy → replace `useast-sub2`
```bash
aws ec2 create-tags --resources useast-sub2 \
  --tags Key=Name,Value=crdb-useast-private-2b --region us-east-1
```

```bash
# Private Subnet 3 — AZ-c
aws ec2 create-subnet --vpc-id vpc-useast \
  --cidr-block 10.1.3.0/24 --availability-zone us-east-1c --region us-east-1
```
> 📋 Copy → replace `useast-sub3`
```bash
aws ec2 create-tags --resources useast-sub3 \
  --tags Key=Name,Value=crdb-useast-private-3c --region us-east-1
```

```bash
# Public Subnet
aws ec2 create-subnet --vpc-id vpc-useast \
  --cidr-block 10.1.100.0/24 --availability-zone us-east-1a --region us-east-1
```
> 📋 Copy → replace `useast-sub-pub`
```bash
aws ec2 create-tags --resources useast-sub-pub \
  --tags Key=Name,Value=crdb-useast-public --region us-east-1

aws ec2 modify-subnet-attribute --subnet-id useast-sub-pub \
  --map-public-ip-on-launch --region us-east-1
```

### Step 2.3: Internet Gateway

```bash
aws ec2 create-internet-gateway --region us-east-1
```
> 📋 Copy → replace `igw-useast`
```bash
aws ec2 create-tags --resources igw-useast \
  --tags Key=Name,Value=crdb-igw-useast --region us-east-1

aws ec2 attach-internet-gateway \
  --internet-gateway-id igw-useast --vpc-id vpc-useast --region us-east-1
```

### Step 2.4: Route Tables

```bash
aws ec2 create-route-table --vpc-id vpc-useast --region us-east-1
```
> 📋 Copy → replace `pub-rt-useast`
```bash
aws ec2 create-tags --resources pub-rt-useast \
  --tags Key=Name,Value=crdb-public-rt-useast --region us-east-1

aws ec2 create-route --route-table-id pub-rt-useast \
  --destination-cidr-block 0.0.0.0/0 --gateway-id igw-useast --region us-east-1

aws ec2 associate-route-table --route-table-id pub-rt-useast \
  --subnet-id useast-sub-pub --region us-east-1
```

```bash
aws ec2 create-route-table --vpc-id vpc-useast --region us-east-1
```
> 📋 Copy → replace `priv-rt-useast`
```bash
aws ec2 create-tags --resources priv-rt-useast \
  --tags Key=Name,Value=crdb-private-rt-useast --region us-east-1

aws ec2 associate-route-table --route-table-id priv-rt-useast \
  --subnet-id useast-sub1 --region us-east-1
aws ec2 associate-route-table --route-table-id priv-rt-useast \
  --subnet-id useast-sub2 --region us-east-1
aws ec2 associate-route-table --route-table-id priv-rt-useast \
  --subnet-id useast-sub3 --region us-east-1
```

### Step 2.5: NAT Gateway

```bash
aws ec2 allocate-address --domain vpc --region us-east-1
```
> 📋 Copy `AllocationId` → replace `eip-useast`
```bash
aws ec2 create-tags --resources eip-useast \
  --tags Key=Name,Value=crdb-eip-useast --region us-east-1

aws ec2 create-nat-gateway --subnet-id useast-sub-pub \
  --allocation-id eip-useast --region us-east-1
```
> 📋 Copy `NatGatewayId` → replace `nat-useast`
```bash
aws ec2 create-tags --resources nat-useast \
  --tags Key=Name,Value=crdb-nat-useast --region us-east-1

aws ec2 wait nat-gateway-available --nat-gateway-ids nat-useast --region us-east-1

aws ec2 create-route --route-table-id priv-rt-useast \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id nat-useast --region us-east-1
```

### Step 2.6: Security Groups

```bash
aws ec2 create-security-group --group-name crdb-sg-useast \
  --description "CockroachDB nodes US-East" --vpc-id vpc-useast --region us-east-1
```
> 📋 Copy → replace `crdb-sg-useast`
```bash
aws ec2 create-tags --resources crdb-sg-useast \
  --tags Key=Name,Value=crdb-sg-useast --region us-east-1

# CockroachDB port from all 3 regions
aws ec2 authorize-security-group-ingress --group-id crdb-sg-useast \
  --protocol tcp --port 26257 --cidr 10.0.0.0/16 --region us-east-1
aws ec2 authorize-security-group-ingress --group-id crdb-sg-useast \
  --protocol tcp --port 26257 --cidr 10.1.0.0/16 --region us-east-1
aws ec2 authorize-security-group-ingress --group-id crdb-sg-useast \
  --protocol tcp --port 26257 --cidr 10.2.0.0/16 --region us-east-1

# Admin UI from all 3 regions
aws ec2 authorize-security-group-ingress --group-id crdb-sg-useast \
  --protocol tcp --port 8080 --cidr 10.0.0.0/16 --region us-east-1
aws ec2 authorize-security-group-ingress --group-id crdb-sg-useast \
  --protocol tcp --port 8080 --cidr 10.1.0.0/16 --region us-east-1
aws ec2 authorize-security-group-ingress --group-id crdb-sg-useast \
  --protocol tcp --port 8080 --cidr 10.2.0.0/16 --region us-east-1

# SSH
aws ec2 authorize-security-group-ingress --group-id crdb-sg-useast \
  --protocol tcp --port 22 --cidr 10.1.0.0/16 --region us-east-1
```

```bash
aws ec2 create-security-group --group-name bastion-sg-useast \
  --description "Bastion SSH US-East" --vpc-id vpc-useast --region us-east-1
```
> 📋 Copy → replace `bastion-sg-useast`
```bash
aws ec2 create-tags --resources bastion-sg-useast \
  --tags Key=Name,Value=crdb-bastion-sg-useast --region us-east-1

aws ec2 authorize-security-group-ingress --group-id bastion-sg-useast \
  --protocol tcp --port 22 --cidr YOUR_IP/32 --region us-east-1
```

### Step 2.7: Key Pair & AMI

```bash
aws ec2 create-key-pair --key-name crdb-key-useast \
  --query 'KeyMaterial' --output text \
  --region us-east-1 > crdb-key-useast.pem
chmod 400 crdb-key-useast.pem

aws ec2 describe-images --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text --region us-east-1
```
> 📋 Copy AMI → replace `ami-useast`

### Step 2.8: Launch Instances

```bash
# Node 4 — US-East AZ-a (10.1.1.10)
aws ec2 run-instances --image-id ami-useast --instance-type t3.medium \
  --key-name crdb-key-useast --subnet-id useast-sub1 \
  --private-ip-address 10.1.1.10 --security-group-ids crdb-sg-useast \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region us-east-1
```
> 📋 Copy → replace `useast-node1`
```bash
aws ec2 create-tags --resources useast-node1 \
  --tags Key=Name,Value=crdb-useast-node1 --region us-east-1
```

```bash
# Node 5 — US-East AZ-b (10.1.2.10)
aws ec2 run-instances --image-id ami-useast --instance-type t3.medium \
  --key-name crdb-key-useast --subnet-id useast-sub2 \
  --private-ip-address 10.1.2.10 --security-group-ids crdb-sg-useast \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region us-east-1
```
> 📋 Copy → replace `useast-node2`
```bash
aws ec2 create-tags --resources useast-node2 \
  --tags Key=Name,Value=crdb-useast-node2 --region us-east-1
```

```bash
# Node 6 — US-East AZ-c (10.1.3.10)
aws ec2 run-instances --image-id ami-useast --instance-type t3.medium \
  --key-name crdb-key-useast --subnet-id useast-sub3 \
  --private-ip-address 10.1.3.10 --security-group-ids crdb-sg-useast \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region us-east-1
```
> 📋 Copy → replace `useast-node3`
```bash
aws ec2 create-tags --resources useast-node3 \
  --tags Key=Name,Value=crdb-useast-node3 --region us-east-1
```

```bash
# Bastion — US-East
aws ec2 run-instances --image-id ami-useast --instance-type t3.micro \
  --key-name crdb-key-useast --subnet-id useast-sub-pub \
  --security-group-ids bastion-sg-useast --associate-public-ip-address \
  --region us-east-1
```
> 📋 Copy → replace `useast-bastion`
```bash
aws ec2 create-tags --resources useast-bastion \
  --tags Key=Name,Value=crdb-bastion-useast --region us-east-1
```

---

## REGION 3: MUMBAI (ap-south-1)

> Same pattern. All commands ready.

### Step 3.1–3.5: VPC + Subnets + IGW + Routes + NAT

```bash
# ─── VPC ───
aws ec2 create-vpc --cidr-block 10.2.0.0/16 --region ap-south-1
# 📋 Copy VpcId → replace vpc-mumbai

aws ec2 create-tags --resources vpc-mumbai \
  --tags Key=Name,Value=crdb-vpc-mumbai --region ap-south-1
aws ec2 modify-vpc-attribute --vpc-id vpc-mumbai \
  --enable-dns-hostnames --region ap-south-1
aws ec2 modify-vpc-attribute --vpc-id vpc-mumbai \
  --enable-dns-support --region ap-south-1

# ─── Private Subnets ───
aws ec2 create-subnet --vpc-id vpc-mumbai \
  --cidr-block 10.2.1.0/24 --availability-zone ap-south-1a --region ap-south-1
# 📋 → mumbai-sub1
aws ec2 create-tags --resources mumbai-sub1 \
  --tags Key=Name,Value=crdb-mumbai-private-1a --region ap-south-1

aws ec2 create-subnet --vpc-id vpc-mumbai \
  --cidr-block 10.2.2.0/24 --availability-zone ap-south-1b --region ap-south-1
# 📋 → mumbai-sub2
aws ec2 create-tags --resources mumbai-sub2 \
  --tags Key=Name,Value=crdb-mumbai-private-2b --region ap-south-1

aws ec2 create-subnet --vpc-id vpc-mumbai \
  --cidr-block 10.2.3.0/24 --availability-zone ap-south-1c --region ap-south-1
# 📋 → mumbai-sub3
aws ec2 create-tags --resources mumbai-sub3 \
  --tags Key=Name,Value=crdb-mumbai-private-3c --region ap-south-1

aws ec2 create-subnet --vpc-id vpc-mumbai \
  --cidr-block 10.2.100.0/24 --availability-zone ap-south-1a --region ap-south-1
# 📋 → mumbai-sub-pub
aws ec2 create-tags --resources mumbai-sub-pub \
  --tags Key=Name,Value=crdb-mumbai-public --region ap-south-1
aws ec2 modify-subnet-attribute --subnet-id mumbai-sub-pub \
  --map-public-ip-on-launch --region ap-south-1

# ─── Internet Gateway ───
aws ec2 create-internet-gateway --region ap-south-1
# 📋 → igw-mumbai
aws ec2 create-tags --resources igw-mumbai \
  --tags Key=Name,Value=crdb-igw-mumbai --region ap-south-1
aws ec2 attach-internet-gateway --internet-gateway-id igw-mumbai \
  --vpc-id vpc-mumbai --region ap-south-1

# ─── Public Route Table ───
aws ec2 create-route-table --vpc-id vpc-mumbai --region ap-south-1
# 📋 → pub-rt-mumbai
aws ec2 create-tags --resources pub-rt-mumbai \
  --tags Key=Name,Value=crdb-public-rt-mumbai --region ap-south-1
aws ec2 create-route --route-table-id pub-rt-mumbai \
  --destination-cidr-block 0.0.0.0/0 --gateway-id igw-mumbai --region ap-south-1
aws ec2 associate-route-table --route-table-id pub-rt-mumbai \
  --subnet-id mumbai-sub-pub --region ap-south-1

# ─── Private Route Table ───
aws ec2 create-route-table --vpc-id vpc-mumbai --region ap-south-1
# 📋 → priv-rt-mumbai
aws ec2 create-tags --resources priv-rt-mumbai \
  --tags Key=Name,Value=crdb-private-rt-mumbai --region ap-south-1
aws ec2 associate-route-table --route-table-id priv-rt-mumbai \
  --subnet-id mumbai-sub1 --region ap-south-1
aws ec2 associate-route-table --route-table-id priv-rt-mumbai \
  --subnet-id mumbai-sub2 --region ap-south-1
aws ec2 associate-route-table --route-table-id priv-rt-mumbai \
  --subnet-id mumbai-sub3 --region ap-south-1

# ─── NAT Gateway ───
aws ec2 allocate-address --domain vpc --region ap-south-1
# 📋 → eip-mumbai
aws ec2 create-tags --resources eip-mumbai \
  --tags Key=Name,Value=crdb-eip-mumbai --region ap-south-1

aws ec2 create-nat-gateway --subnet-id mumbai-sub-pub \
  --allocation-id eip-mumbai --region ap-south-1
# 📋 → nat-mumbai
aws ec2 create-tags --resources nat-mumbai \
  --tags Key=Name,Value=crdb-nat-mumbai --region ap-south-1
aws ec2 wait nat-gateway-available --nat-gateway-ids nat-mumbai --region ap-south-1
aws ec2 create-route --route-table-id priv-rt-mumbai \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id nat-mumbai --region ap-south-1
```

### Step 3.6: Security Groups

```bash
aws ec2 create-security-group --group-name crdb-sg-mumbai \
  --description "CockroachDB nodes Mumbai" --vpc-id vpc-mumbai --region ap-south-1
# 📋 → crdb-sg-mumbai
aws ec2 create-tags --resources crdb-sg-mumbai \
  --tags Key=Name,Value=crdb-sg-mumbai --region ap-south-1

# CockroachDB port from all 3 regions
aws ec2 authorize-security-group-ingress --group-id crdb-sg-mumbai \
  --protocol tcp --port 26257 --cidr 10.0.0.0/16 --region ap-south-1
aws ec2 authorize-security-group-ingress --group-id crdb-sg-mumbai \
  --protocol tcp --port 26257 --cidr 10.1.0.0/16 --region ap-south-1
aws ec2 authorize-security-group-ingress --group-id crdb-sg-mumbai \
  --protocol tcp --port 26257 --cidr 10.2.0.0/16 --region ap-south-1

# Admin UI from all 3 regions
aws ec2 authorize-security-group-ingress --group-id crdb-sg-mumbai \
  --protocol tcp --port 8080 --cidr 10.0.0.0/16 --region ap-south-1
aws ec2 authorize-security-group-ingress --group-id crdb-sg-mumbai \
  --protocol tcp --port 8080 --cidr 10.1.0.0/16 --region ap-south-1
aws ec2 authorize-security-group-ingress --group-id crdb-sg-mumbai \
  --protocol tcp --port 8080 --cidr 10.2.0.0/16 --region ap-south-1

# SSH
aws ec2 authorize-security-group-ingress --group-id crdb-sg-mumbai \
  --protocol tcp --port 22 --cidr 10.2.0.0/16 --region ap-south-1

# Bastion
aws ec2 create-security-group --group-name bastion-sg-mumbai \
  --description "Bastion SSH Mumbai" --vpc-id vpc-mumbai --region ap-south-1
# 📋 → bastion-sg-mumbai
aws ec2 create-tags --resources bastion-sg-mumbai \
  --tags Key=Name,Value=crdb-bastion-sg-mumbai --region ap-south-1
aws ec2 authorize-security-group-ingress --group-id bastion-sg-mumbai \
  --protocol tcp --port 22 --cidr YOUR_IP/32 --region ap-south-1
```

### Step 3.7: Key Pair & AMI

```bash
aws ec2 create-key-pair --key-name crdb-key-mumbai \
  --query 'KeyMaterial' --output text \
  --region ap-south-1 > crdb-key-mumbai.pem
chmod 400 crdb-key-mumbai.pem

aws ec2 describe-images --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text --region ap-south-1
```
> 📋 Copy AMI → replace `ami-mumbai`

### Step 3.8: Launch Instances

```bash
# Node 7 — Mumbai AZ-a (10.2.1.10)
aws ec2 run-instances --image-id ami-mumbai --instance-type t3.medium \
  --key-name crdb-key-mumbai --subnet-id mumbai-sub1 \
  --private-ip-address 10.2.1.10 --security-group-ids crdb-sg-mumbai \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region ap-south-1
# 📋 → mumbai-node1
aws ec2 create-tags --resources mumbai-node1 \
  --tags Key=Name,Value=crdb-mumbai-node1 --region ap-south-1

# Node 8 — Mumbai AZ-b (10.2.2.10)
aws ec2 run-instances --image-id ami-mumbai --instance-type t3.medium \
  --key-name crdb-key-mumbai --subnet-id mumbai-sub2 \
  --private-ip-address 10.2.2.10 --security-group-ids crdb-sg-mumbai \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region ap-south-1
# 📋 → mumbai-node2
aws ec2 create-tags --resources mumbai-node2 \
  --tags Key=Name,Value=crdb-mumbai-node2 --region ap-south-1

# Node 9 — Mumbai AZ-c (10.2.3.10)
aws ec2 run-instances --image-id ami-mumbai --instance-type t3.medium \
  --key-name crdb-key-mumbai --subnet-id mumbai-sub3 \
  --private-ip-address 10.2.3.10 --security-group-ids crdb-sg-mumbai \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":50,"VolumeType":"gp3"}}]' \
  --region ap-south-1
# 📋 → mumbai-node3
aws ec2 create-tags --resources mumbai-node3 \
  --tags Key=Name,Value=crdb-mumbai-node3 --region ap-south-1

# Bastion — Mumbai
aws ec2 run-instances --image-id ami-mumbai --instance-type t3.micro \
  --key-name crdb-key-mumbai --subnet-id mumbai-sub-pub \
  --security-group-ids bastion-sg-mumbai --associate-public-ip-address \
  --region ap-south-1
# 📋 → mumbai-bastion
aws ec2 create-tags --resources mumbai-bastion \
  --tags Key=Name,Value=crdb-bastion-mumbai --region ap-south-1
```

---

## VPC PEERING (Connect All 3 Regions)

This is the **critical step** that allows nodes in different regions to talk to each other.

```
     Paris (10.0.0.0/16)
       │              │
  Peering-1       Peering-3
       │              │
  US-East ──────── Mumbai
  (10.1.0.0/16)  Peering-2  (10.2.0.0/16)
```

### Peering 1: Paris ↔ US-East

```bash
# Create peering request (from Paris → US-East)
aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-paris \
  --peer-vpc-id vpc-useast \
  --peer-region us-east-1 \
  --region eu-west-3
```
> 📋 Copy `VpcPeeringConnectionId` → replace `pcx-paris-useast`
```bash
aws ec2 create-tags --resources pcx-paris-useast \
  --tags Key=Name,Value=crdb-peer-paris-useast --region eu-west-3

# Accept peering in US-East region
aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id pcx-paris-useast \
  --region us-east-1

# Add routes — Paris private route table → US-East CIDR via peering
aws ec2 create-route \
  --route-table-id priv-rt-paris \
  --destination-cidr-block 10.1.0.0/16 \
  --vpc-peering-connection-id pcx-paris-useast \
  --region eu-west-3

# Add routes — US-East private route table → Paris CIDR via peering
aws ec2 create-route \
  --route-table-id priv-rt-useast \
  --destination-cidr-block 10.0.0.0/16 \
  --vpc-peering-connection-id pcx-paris-useast \
  --region us-east-1
```

### Peering 2: US-East ↔ Mumbai

```bash
aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-useast \
  --peer-vpc-id vpc-mumbai \
  --peer-region ap-south-1 \
  --region us-east-1
```
> 📋 Copy → replace `pcx-useast-mumbai`
```bash
aws ec2 create-tags --resources pcx-useast-mumbai \
  --tags Key=Name,Value=crdb-peer-useast-mumbai --region us-east-1

aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id pcx-useast-mumbai \
  --region ap-south-1

# Routes
aws ec2 create-route --route-table-id priv-rt-useast \
  --destination-cidr-block 10.2.0.0/16 \
  --vpc-peering-connection-id pcx-useast-mumbai --region us-east-1

aws ec2 create-route --route-table-id priv-rt-mumbai \
  --destination-cidr-block 10.1.0.0/16 \
  --vpc-peering-connection-id pcx-useast-mumbai --region ap-south-1
```

### Peering 3: Paris ↔ Mumbai

```bash
aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-paris \
  --peer-vpc-id vpc-mumbai \
  --peer-region ap-south-1 \
  --region eu-west-3
```
> 📋 Copy → replace `pcx-paris-mumbai`
```bash
aws ec2 create-tags --resources pcx-paris-mumbai \
  --tags Key=Name,Value=crdb-peer-paris-mumbai --region eu-west-3

aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id pcx-paris-mumbai \
  --region ap-south-1

# Routes
aws ec2 create-route --route-table-id priv-rt-paris \
  --destination-cidr-block 10.2.0.0/16 \
  --vpc-peering-connection-id pcx-paris-mumbai --region eu-west-3

aws ec2 create-route --route-table-id priv-rt-mumbai \
  --destination-cidr-block 10.0.0.0/16 \
  --vpc-peering-connection-id pcx-paris-mumbai --region ap-south-1
```

### Verify Peering

```bash
# From Paris Bastion → SSH to Paris Node 1
ssh ubuntu@10.0.1.10

# Test cross-region connectivity
ping -c 3 10.1.1.10    # → US-East Node 4
ping -c 3 10.2.1.10    # → Mumbai Node 7
```

---

## INSTALL COCKROACHDB ON ALL 9 NODES

> SSH into each node via its regional Bastion and run these commands.

### On Every Node (All 9):

```bash
# Download CockroachDB
curl https://binaries.cockroachdb.com/cockroach-v24.3.1.linux-amd64.tgz | tar -xz

# Move binary to PATH
sudo cp cockroach-v24.3.1.linux-amd64/cockroach /usr/local/bin/
sudo mkdir -p /usr/local/lib/cockroach
sudo cp cockroach-v24.3.1.linux-amd64/lib/* /usr/local/lib/cockroach/

# Verify
cockroach version

# Create data directory
sudo mkdir -p /var/lib/cockroach
sudo chown ubuntu:ubuntu /var/lib/cockroach
```

### Generate Certificates (On any one node, e.g., Paris Node 1)

```bash
# Create certs directory
mkdir -p certs my-safe-directory

# Create CA certificate
cockroach cert create-ca \
  --certs-dir=certs \
  --ca-key=my-safe-directory/ca.key

# Create node certificates for ALL 9 nodes
# Paris Nodes
cockroach cert create-node \
  10.0.1.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
# Move & rename for Node 1
mkdir -p node-certs/paris-node1 && mv certs/node.* node-certs/paris-node1/

cockroach cert create-node \
  10.0.2.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
mkdir -p node-certs/paris-node2 && mv certs/node.* node-certs/paris-node2/

cockroach cert create-node \
  10.0.3.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
mkdir -p node-certs/paris-node3 && mv certs/node.* node-certs/paris-node3/

# US-East Nodes
cockroach cert create-node \
  10.1.1.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
mkdir -p node-certs/useast-node1 && mv certs/node.* node-certs/useast-node1/

cockroach cert create-node \
  10.1.2.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
mkdir -p node-certs/useast-node2 && mv certs/node.* node-certs/useast-node2/

cockroach cert create-node \
  10.1.3.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
mkdir -p node-certs/useast-node3 && mv certs/node.* node-certs/useast-node3/

# Mumbai Nodes
cockroach cert create-node \
  10.2.1.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
mkdir -p node-certs/mumbai-node1 && mv certs/node.* node-certs/mumbai-node1/

cockroach cert create-node \
  10.2.2.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
mkdir -p node-certs/mumbai-node2 && mv certs/node.* node-certs/mumbai-node2/

cockroach cert create-node \
  10.2.3.10 localhost 127.0.0.1 \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
mkdir -p node-certs/mumbai-node3 && mv certs/node.* node-certs/mumbai-node3/

# Create root client certificate
cockroach cert create-client root \
  --certs-dir=certs --ca-key=my-safe-directory/ca.key
```

### Distribute Certificates

```bash
# Copy ca.crt + node certs to each node
# Example: Copy to Paris Node 2
scp certs/ca.crt node-certs/paris-node2/* ubuntu@10.0.2.10:~/certs/

# Repeat for all 9 nodes with their respective cert folders
# On each node after copying:
mkdir -p ~/certs
# (files should be in ~/certs: ca.crt, node.crt, node.key)
```

### Start CockroachDB on Each Node

The `--join` flag lists at least one node from each region so the cluster can bootstrap.

```bash
# ═══════════════════════════════════════
# PARIS NODE 1 (10.0.1.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.0.1.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=eu-west-3,zone=eu-west-3a \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background

# ═══════════════════════════════════════
# PARIS NODE 2 (10.0.2.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.0.2.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=eu-west-3,zone=eu-west-3b \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background

# ═══════════════════════════════════════
# PARIS NODE 3 (10.0.3.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.0.3.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=eu-west-3,zone=eu-west-3c \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background

# ═══════════════════════════════════════
# US-EAST NODE 4 (10.1.1.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.1.1.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=us-east-1,zone=us-east-1a \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background

# ═══════════════════════════════════════
# US-EAST NODE 5 (10.1.2.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.1.2.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=us-east-1,zone=us-east-1b \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background

# ═══════════════════════════════════════
# US-EAST NODE 6 (10.1.3.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.1.3.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=us-east-1,zone=us-east-1c \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background

# ═══════════════════════════════════════
# MUMBAI NODE 7 (10.2.1.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.2.1.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=ap-south-1,zone=ap-south-1a \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background

# ═══════════════════════════════════════
# MUMBAI NODE 8 (10.2.2.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.2.2.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=ap-south-1,zone=ap-south-1b \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background

# ═══════════════════════════════════════
# MUMBAI NODE 9 (10.2.3.10)
# ═══════════════════════════════════════
cockroach start \
  --certs-dir=certs \
  --advertise-addr=10.2.3.10 \
  --join=10.0.1.10,10.0.2.10,10.0.3.10,10.1.1.10,10.1.2.10,10.1.3.10,10.2.1.10,10.2.2.10,10.2.3.10 \
  --locality=region=ap-south-1,zone=ap-south-1c \
  --store=/var/lib/cockroach \
  --cache=.25 \
  --max-sql-memory=.25 \
  --background
```

### Initialize the Cluster (Run ONCE on any node)

```bash
# Run this ONLY ONCE from any node (e.g., Paris Node 1)
cockroach init --certs-dir=certs --host=10.0.1.10
```

---

## VERIFY THE CLUSTER

### Check Node Status

```bash
cockroach node status --certs-dir=certs --host=10.0.1.10
```

Expected output:
```
  id | address     | sql_address | build   | started_at | locality                              | is_live
+----+-------------+-------------+---------+------------+---------------------------------------+---------+
   1 | 10.0.1.10   | 10.0.1.10   | v24.3.1 | ...        | region=eu-west-3,zone=eu-west-3a      | true
   2 | 10.0.2.10   | 10.0.2.10   | v24.3.1 | ...        | region=eu-west-3,zone=eu-west-3b      | true
   3 | 10.0.3.10   | 10.0.3.10   | v24.3.1 | ...        | region=eu-west-3,zone=eu-west-3c      | true
   4 | 10.1.1.10   | 10.1.1.10   | v24.3.1 | ...        | region=us-east-1,zone=us-east-1a      | true
   5 | 10.1.2.10   | 10.1.2.10   | v24.3.1 | ...        | region=us-east-1,zone=us-east-1b      | true
   6 | 10.1.3.10   | 10.1.3.10   | v24.3.1 | ...        | region=us-east-1,zone=us-east-1c      | true
   7 | 10.2.1.10   | 10.2.1.10   | v24.3.1 | ...        | region=ap-south-1,zone=ap-south-1a    | true
   8 | 10.2.2.10   | 10.2.2.10   | v24.3.1 | ...        | region=ap-south-1,zone=ap-south-1b    | true
   9 | 10.2.3.10   | 10.2.3.10   | v24.3.1 | ...        | region=ap-south-1,zone=ap-south-1c    | true
(9 rows)
```

### Connect to SQL Shell

```bash
cockroach sql --certs-dir=certs --host=10.0.1.10
```

### Create a Multi-Region Database

```sql
-- Add region definitions
ALTER DATABASE defaultdb SET PRIMARY REGION "eu-west-3";
ALTER DATABASE defaultdb ADD REGION "us-east-1";
ALTER DATABASE defaultdb ADD REGION "ap-south-1";

-- Set survival goal (survive entire region failure)
ALTER DATABASE defaultdb SURVIVE REGION FAILURE;

-- Create a test table
CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name STRING NOT NULL,
    email STRING NOT NULL,
    region STRING NOT NULL,
    created_at TIMESTAMP DEFAULT now()
);

-- Insert test data
INSERT INTO users (name, email, region) VALUES
    ('Pierre', 'pierre@example.com', 'eu-west-3'),
    ('John', 'john@example.com', 'us-east-1'),
    ('Priya', 'priya@example.com', 'ap-south-1');

-- Verify data from any node
SELECT * FROM users;
```

### Access Admin UI

```bash
# SSH tunnel from your local machine through Bastion
ssh -i crdb-key-paris.pem -L 8080:10.0.1.10:8080 ubuntu@PARIS_BASTION_IP

# Open in browser: http://localhost:8080
```

---

## COMPLETE CLEANUP (All 3 Regions)

> **⚠️ Run in order! NAT Gateways take ~60 seconds to delete.**

### Delete VPC Peering

```bash
aws ec2 delete-vpc-peering-connection \
  --vpc-peering-connection-id pcx-paris-useast --region eu-west-3
aws ec2 delete-vpc-peering-connection \
  --vpc-peering-connection-id pcx-useast-mumbai --region us-east-1
aws ec2 delete-vpc-peering-connection \
  --vpc-peering-connection-id pcx-paris-mumbai --region eu-west-3
```

### Cleanup Paris

```bash
# Terminate instances
aws ec2 terminate-instances \
  --instance-ids paris-node1 paris-node2 paris-node3 paris-bastion \
  --region eu-west-3
aws ec2 wait instance-terminated \
  --instance-ids paris-node1 paris-node2 paris-node3 paris-bastion \
  --region eu-west-3

# Delete NAT Gateway (wait 60s)
aws ec2 delete-nat-gateway --nat-gateway-id nat-paris --region eu-west-3
sleep 60

# Release Elastic IP
aws ec2 release-address --allocation-id eip-paris --region eu-west-3

# Detach & Delete Internet Gateway
aws ec2 detach-internet-gateway \
  --internet-gateway-id igw-paris --vpc-id vpc-paris --region eu-west-3
aws ec2 delete-internet-gateway \
  --internet-gateway-id igw-paris --region eu-west-3

# Delete Subnets
aws ec2 delete-subnet --subnet-id paris-sub1 --region eu-west-3
aws ec2 delete-subnet --subnet-id paris-sub2 --region eu-west-3
aws ec2 delete-subnet --subnet-id paris-sub3 --region eu-west-3
aws ec2 delete-subnet --subnet-id paris-sub-pub --region eu-west-3

# Delete Route Tables
aws ec2 delete-route-table --route-table-id pub-rt-paris --region eu-west-3
aws ec2 delete-route-table --route-table-id priv-rt-paris --region eu-west-3

# Delete Security Groups
aws ec2 delete-security-group --group-id crdb-sg-paris --region eu-west-3
aws ec2 delete-security-group --group-id bastion-sg-paris --region eu-west-3

# Delete VPC
aws ec2 delete-vpc --vpc-id vpc-paris --region eu-west-3

# Delete Key Pair
aws ec2 delete-key-pair --key-name crdb-key-paris --region eu-west-3
rm crdb-key-paris.pem
```

### Cleanup US-East

```bash
aws ec2 terminate-instances \
  --instance-ids useast-node1 useast-node2 useast-node3 useast-bastion \
  --region us-east-1
aws ec2 wait instance-terminated \
  --instance-ids useast-node1 useast-node2 useast-node3 useast-bastion \
  --region us-east-1

aws ec2 delete-nat-gateway --nat-gateway-id nat-useast --region us-east-1
sleep 60
aws ec2 release-address --allocation-id eip-useast --region us-east-1
aws ec2 detach-internet-gateway \
  --internet-gateway-id igw-useast --vpc-id vpc-useast --region us-east-1
aws ec2 delete-internet-gateway --internet-gateway-id igw-useast --region us-east-1

aws ec2 delete-subnet --subnet-id useast-sub1 --region us-east-1
aws ec2 delete-subnet --subnet-id useast-sub2 --region us-east-1
aws ec2 delete-subnet --subnet-id useast-sub3 --region us-east-1
aws ec2 delete-subnet --subnet-id useast-sub-pub --region us-east-1

aws ec2 delete-route-table --route-table-id pub-rt-useast --region us-east-1
aws ec2 delete-route-table --route-table-id priv-rt-useast --region us-east-1

aws ec2 delete-security-group --group-id crdb-sg-useast --region us-east-1
aws ec2 delete-security-group --group-id bastion-sg-useast --region us-east-1

aws ec2 delete-vpc --vpc-id vpc-useast --region us-east-1
aws ec2 delete-key-pair --key-name crdb-key-useast --region us-east-1
rm crdb-key-useast.pem
```

### Cleanup Mumbai

```bash
aws ec2 terminate-instances \
  --instance-ids mumbai-node1 mumbai-node2 mumbai-node3 mumbai-bastion \
  --region ap-south-1
aws ec2 wait instance-terminated \
  --instance-ids mumbai-node1 mumbai-node2 mumbai-node3 mumbai-bastion \
  --region ap-south-1

aws ec2 delete-nat-gateway --nat-gateway-id nat-mumbai --region ap-south-1
sleep 60
aws ec2 release-address --allocation-id eip-mumbai --region ap-south-1
aws ec2 detach-internet-gateway \
  --internet-gateway-id igw-mumbai --vpc-id vpc-mumbai --region ap-south-1
aws ec2 delete-internet-gateway --internet-gateway-id igw-mumbai --region ap-south-1

aws ec2 delete-subnet --subnet-id mumbai-sub1 --region ap-south-1
aws ec2 delete-subnet --subnet-id mumbai-sub2 --region ap-south-1
aws ec2 delete-subnet --subnet-id mumbai-sub3 --region ap-south-1
aws ec2 delete-subnet --subnet-id mumbai-sub-pub --region ap-south-1

aws ec2 delete-route-table --route-table-id pub-rt-mumbai --region ap-south-1
aws ec2 delete-route-table --route-table-id priv-rt-mumbai --region ap-south-1

aws ec2 delete-security-group --group-id crdb-sg-mumbai --region ap-south-1
aws ec2 delete-security-group --group-id bastion-sg-mumbai --region ap-south-1

aws ec2 delete-vpc --vpc-id vpc-mumbai --region ap-south-1
aws ec2 delete-key-pair --key-name crdb-key-mumbai --region ap-south-1
rm crdb-key-mumbai.pem
```

---

## Quick Reference: Resource Count

| Resource | Per Region | Total (3 Regions) |
|----------|-----------|-------------------|
| VPCs | 1 | 3 |
| Private Subnets | 3 | 9 |
| Public Subnets | 1 | 3 |
| Internet Gateways | 1 | 3 |
| NAT Gateways | 1 | 3 |
| Elastic IPs | 1 | 3 |
| Route Tables | 2 | 6 |
| Security Groups | 2 | 6 |
| Key Pairs | 1 | 3 |
| DB Instances (t3.medium) | 3 | **9** |
| Bastion Instances (t3.micro) | 1 | 3 |
| VPC Peering Connections | — | **3** |
| **Total EC2 Instances** | **4** | **12** |

---

## Estimated Monthly Cost

| Resource | Per Region | Total (3 Regions) |
|----------|-----------|-------------------|
| 3× t3.medium (CockroachDB) | ~$92/mo | ~$276/mo |
| 1× t3.micro (Bastion) | ~$8/mo | ~$24/mo |
| NAT Gateway | ~$32/mo + data | ~$96/mo |
| 50GB gp3 × 3 nodes | ~$12/mo | ~$36/mo |
| Elastic IPs | ~$3.60/mo | ~$10.80/mo |
| VPC Peering data transfer | ~$0.01/GB | variable |
| **Total Estimate** | ~$148/mo | **~$443/mo** |

> **💡 Cost Tip:** Use Reserved Instances or Spot Instances for nodes to save 40-70%. Delete NAT Gateways when not needed. Use t3.small for testing.

---

*Multi-Region CockroachDB 9-Node Cluster · AWS CLI Complete Guide*
