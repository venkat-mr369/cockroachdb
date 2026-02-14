# AWS Infrastructure Setup — Paris (eu-west-3)

---

## Step 1: Create VPC

```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region eu-west-3
```
Note the VpcId from output:
```bash
export VPC_ID="vpc-xxxxx"
```

Tag it:
```bash
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=paris-vpc
```

Enable DNS:
```bash
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
```

---

## Step 2: Create Subnets (3 Private + 1 Public)

### Private Subnet 1 (for db1)
```bash
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone eu-west-3a
export PRIV_SUB_1="subnet-xxxxx"
aws ec2 create-tags --resources $PRIV_SUB_1 --tags Key=Name,Value=paris-private-1
```

### Private Subnet 2 (for db2)
```bash
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone eu-west-3b
export PRIV_SUB_2="subnet-xxxxx"
aws ec2 create-tags --resources $PRIV_SUB_2 --tags Key=Name,Value=paris-private-2
```

### Private Subnet 3 (for db3)
```bash
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 --availability-zone eu-west-3c
export PRIV_SUB_3="subnet-xxxxx"
aws ec2 create-tags --resources $PRIV_SUB_3 --tags Key=Name,Value=paris-private-3
```

### Public Subnet (for NAT + Bastion)
```bash
aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.100.0/24 --availability-zone eu-west-3a
export PUB_SUB="subnet-xxxxx"
aws ec2 create-tags --resources $PUB_SUB --tags Key=Name,Value=paris-public

aws ec2 modify-subnet-attribute --subnet-id $PUB_SUB --map-public-ip-on-launch
```

---

## Step 3: Create & Attach Internet Gateway

```bash
aws ec2 create-internet-gateway
export IGW="igw-xxxxx"
aws ec2 create-tags --resources $IGW --tags Key=Name,Value=paris-igw

aws ec2 attach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID
```

---

## Step 4: Create Route Tables & Add Routes

### Public Route Table
```bash
aws ec2 create-route-table --vpc-id $VPC_ID
export PUB_RT="rtb-xxxxx"
aws ec2 create-tags --resources $PUB_RT --tags Key=Name,Value=paris-public-rt

aws ec2 create-route --route-table-id $PUB_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW

aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB_SUB
```

### Private Route Table
```bash
aws ec2 create-route-table --vpc-id $VPC_ID
export PRIV_RT="rtb-xxxxx"
aws ec2 create-tags --resources $PRIV_RT --tags Key=Name,Value=paris-private-rt

aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV_SUB_1
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV_SUB_2
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV_SUB_3
```

---

## Step 5: Create NAT Gateway + Elastic IP

```bash
# Allocate Elastic IP
aws ec2 allocate-address --domain vpc
export EIP="eipalloc-xxxxx"
aws ec2 create-tags --resources $EIP --tags Key=Name,Value=paris-nat-eip

# Create NAT Gateway in public subnet
aws ec2 create-nat-gateway --subnet-id $PUB_SUB --allocation-id $EIP
export NAT="nat-xxxxx"
aws ec2 create-tags --resources $NAT --tags Key=Name,Value=paris-nat

# Wait until NAT is ready (1-2 min)
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT

# Add route: private subnets → NAT Gateway
aws ec2 create-route --route-table-id $PRIV_RT --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT
```

---

## Step 6: Create Security Groups

### CockroachDB SG (for private nodes)
```bash
aws ec2 create-security-group --group-name paris-crdb-sg --description "CockroachDB nodes" --vpc-id $VPC_ID
export CRDB_SG="sg-xxxxx"
aws ec2 create-tags --resources $CRDB_SG --tags Key=Name,Value=paris-crdb-sg

aws ec2 authorize-security-group-ingress --group-id $CRDB_SG --protocol tcp --port 26257 --cidr 10.0.0.0/16
aws ec2 authorize-security-group-ingress --group-id $CRDB_SG --protocol tcp --port 8080 --cidr 10.0.0.0/16
aws ec2 authorize-security-group-ingress --group-id $CRDB_SG --protocol tcp --port 22 --cidr 10.0.0.0/16
```

### Bastion SG (for jump host)
```bash
aws ec2 create-security-group --group-name paris-bastion-sg --description "Bastion SSH" --vpc-id $VPC_ID
export BASTION_SG="sg-xxxxx"
aws ec2 create-tags --resources $BASTION_SG --tags Key=Name,Value=paris-bastion-sg

# Replace YOUR_IP with your public IP
aws ec2 authorize-security-group-ingress --group-id $BASTION_SG --protocol tcp --port 22 --cidr YOUR_IP/32
```

---

## Step 7: Create Key Pair

```bash
aws ec2 create-key-pair --key-name paris-key --query 'KeyMaterial' --output text > paris-key.pem
chmod 400 paris-key.pem
```

---

## Step 8: Get AMI & Launch EC2 Instances

### Get Ubuntu 24.04 AMI
```bash
export AMI=$(aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
  --output text)
echo $AMI
```

### Launch db1 (10.0.1.10)
```bash
aws ec2 run-instances \
  --image-id $AMI \
  --instance-type t3.medium \
  --key-name paris-key \
  --subnet-id $PRIV_SUB_1 \
  --private-ip-address 10.0.1.10 \
  --security-group-ids $CRDB_SG
export DB1="i-xxxxx"
aws ec2 create-tags --resources $DB1 --tags Key=Name,Value=paris-db1
```

### Launch db2 (10.0.2.10)
```bash
aws ec2 run-instances \
  --image-id $AMI \
  --instance-type t3.medium \
  --key-name paris-key \
  --subnet-id $PRIV_SUB_2 \
  --private-ip-address 10.0.2.10 \
  --security-group-ids $CRDB_SG
export DB2="i-xxxxx"
aws ec2 create-tags --resources $DB2 --tags Key=Name,Value=paris-db2
```

### Launch db3 (10.0.3.10)
```bash
aws ec2 run-instances \
  --image-id $AMI \
  --instance-type t3.medium \
  --key-name paris-key \
  --subnet-id $PRIV_SUB_3 \
  --private-ip-address 10.0.3.10 \
  --security-group-ids $CRDB_SG
export DB3="i-xxxxx"
aws ec2 create-tags --resources $DB3 --tags Key=Name,Value=paris-db3
```

### Launch Bastion (public)
```bash
aws ec2 run-instances \
  --image-id $AMI \
  --instance-type t3.micro \
  --key-name paris-key \
  --subnet-id $PUB_SUB \
  --security-group-ids $BASTION_SG \
  --associate-public-ip-address
export BASTION="i-xxxxx"
aws ec2 create-tags --resources $BASTION --tags Key=Name,Value=paris-bastion
```

---

## Step 9: Get Bastion Public IP

```bash
aws ec2 wait instance-running --instance-ids $DB1 $DB2 $DB3 $BASTION

aws ec2 describe-instances --instance-ids $BASTION \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

---

## Step 10: Test — SSH & curl google.com

```bash
# Start SSH agent and add key
eval "$(ssh-agent -s)"
ssh-add paris-key.pem

# SSH to bastion (replace BASTION_IP)
ssh -A -i paris-key.pem ubuntu@BASTION_IP

# From bastion, hop to db1
ssh ubuntu@10.0.1.10

# Test internet via NAT Gateway
curl https://www.google.com
curl -I https://www.google.com
ping -c 3 google.com
```

If you see Google HTML or get `200` — NAT Gateway is working.

---

## Architecture

```
              INTERNET
                 │
            ┌────┴────┐
            │paris-igw│
            └────┬────┘
                 │
          ┌──────┴───────┐
          │  paris-vpc    │
          │ 10.0.0.0/16  │
          └──────┬───────┘
                 │
    ┌────────────┼────────────┐
    │            │            │
┌───┴────┐  ┌───┴────┐  ┌───┴────┐    ┌───────────┐
│priv-1  │  │priv-2  │  │priv-3  │    │ public    │
│10.0.1.0│  │10.0.2.0│  │10.0.3.0│    │10.0.100.0 │
│  /24   │  │  /24   │  │  /24   │    │   /24     │
│        │  │        │  │        │    │           │
│ db1    │  │ db2    │  │ db3    │    │ bastion   │
│ .1.10  │  │ .2.10  │  │ .3.10  │    │ nat-gw    │
└────────┘  └────────┘  └────────┘    │ (+ EIP)   │
   3a          3b          3c         └───────────┘
                                          3a
Private RT: 0.0.0.0/0 → NAT
Public RT:  0.0.0.0/0 → IGW
```

---

## Cleanup

```bash
aws ec2 terminate-instances --instance-ids $DB1 $DB2 $DB3 $BASTION
aws ec2 wait instance-terminated --instance-ids $DB1 $DB2 $DB3 $BASTION

aws ec2 delete-nat-gateway --nat-gateway-id $NAT
sleep 60
aws ec2 release-address --allocation-id $EIP

aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW

aws ec2 delete-subnet --subnet-id $PRIV_SUB_1
aws ec2 delete-subnet --subnet-id $PRIV_SUB_2
aws ec2 delete-subnet --subnet-id $PRIV_SUB_3
aws ec2 delete-subnet --subnet-id $PUB_SUB

aws ec2 delete-route-table --route-table-id $PUB_RT
aws ec2 delete-route-table --route-table-id $PRIV_RT

aws ec2 delete-security-group --group-id $CRDB_SG
aws ec2 delete-security-group --group-id $BASTION_SG

aws ec2 delete-vpc --vpc-id $VPC_ID
aws ec2 delete-key-pair --key-name paris-key
rm paris-key.pem
```
