### AWS CLI Lab – Part 2

### Create Three Public Subnets, Associate Route Table, Create Security Group

> **Prerequisite:** Complete Part 1 and make sure you have these variables:
>
> * `VPC_ID`
> * `RT_ID`

---

## Step 11: Create Public Subnet-1

```bash
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.10.1.0/24 \
  --availability-zone ap-south-1a
```

Save the Subnet ID.

```bash
export SUBNET1=subnet-xxxxxxxxxxxxxxxx
```

Name it.

```bash
aws ec2 create-tags \
  --resources $SUBNET1 \
  --tags Key=Name,Value=subnet-a
```

---

## Step 12: Create Public Subnet-2

```bash
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.10.2.0/24 \
  --availability-zone ap-south-1b
```

Save it.

```bash
export SUBNET2=subnet-xxxxxxxxxxxxxxxx
```

Name it.

```bash
aws ec2 create-tags \
  --resources $SUBNET2 \
  --tags Key=Name,Value=subnet-b
```

---

## Step 13: Create Public Subnet-3

```bash
aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block 10.10.3.0/24 \
  --availability-zone ap-south-1c
```

Save it.

```bash
export SUBNET3=subnet-xxxxxxxxxxxxxxxx
```

Name it.

```bash
aws ec2 create-tags \
  --resources $SUBNET3 \
  --tags Key=Name,Value=subnet-c
```

---

## Step 14: Enable Auto Public IP Assignment

Subnet-1

```bash
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET1 \
  --map-public-ip-on-launch
```

Subnet-2

```bash
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET2 \
  --map-public-ip-on-launch
```

Subnet-3

```bash
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET3 \
  --map-public-ip-on-launch
```

---

## Step 15: Associate Route Table

Subnet-1

```bash
aws ec2 associate-route-table \
  --subnet-id $SUBNET1 \
  --route-table-id $RT_ID
```

Subnet-2

```bash
aws ec2 associate-route-table \
  --subnet-id $SUBNET2 \
  --route-table-id $RT_ID
```

Subnet-3

```bash
aws ec2 associate-route-table \
  --subnet-id $SUBNET3 \
  --route-table-id $RT_ID
```

---

## Step 16: Create Security Group

```bash
aws ec2 create-security-group \
  --group-name sg-cockroach \
  --description "CockroachDB Security Group" \
  --vpc-id $VPC_ID
```

Save the Security Group ID.

```bash
export SG_ID=sg-xxxxxxxxxxxxxxxx
```

Name it.

```bash
aws ec2 create-tags \
  --resources $SG_ID \
  --tags Key=Name,Value=sg-cockroach
```

---

## Step 17: Allow SSH

Replace `<YOUR_PUBLIC_IP>/32` with your public IP (for example, `203.0.113.25/32`).

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr <YOUR_PUBLIC_IP>/32
```

---

## Step 18: Allow CockroachDB SQL Port

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 26257 \
  --cidr 10.10.0.0/16
```

---

## Step 19: Allow CockroachDB Admin UI

For a lab:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 8080 \
  --cidr <YOUR_PUBLIC_IP>/32
```

---

## Step 20: Allow ICMP (Ping)

```bash
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol icmp \
  --port -1 \
  --cidr 10.10.0.0/16
```

---

## Step 21: Verify Security Group Rules

```bash
aws ec2 describe-security-groups \
  --group-ids $SG_ID
```

---

## Step 22: Verify Subnets

```bash
aws ec2 describe-subnets \
  --subnet-ids \
  $SUBNET1 \
  $SUBNET2 \
  $SUBNET3
```

---

## Verify Part 2

At the end of Part 2, you should have:

* ✅ 3 Public Subnets

  * `subnet-a` (10.10.1.0/24)
  * `subnet-b` (10.10.2.0/24)
  * `subnet-c` (10.10.3.0/24)
* ✅ Public IP assignment enabled on all subnets
* ✅ Route table associated with all three subnets
* ✅ Security Group (`sg-cockroach`)
* ✅ Firewall rules for:

  * SSH (22)
  * CockroachDB SQL (26257)
  * CockroachDB Admin UI (8080)
  * ICMP (Ping)
