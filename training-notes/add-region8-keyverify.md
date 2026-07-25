### Step 4: Verify and Import EC2 Key Pair (Region-B)

> **EC2 Key Pairs are regional resources.** The `crdb-key` created in **Mumbai (ap-south-1)** is **not automatically available** in **Singapore (ap-southeast-1)**. Before launching Node5 and Node6, verify that the key exists in the Singapore region.

---

## Step 4.1: Verify Key Pair in Mumbai

```bash
aws ec2 describe-key-pairs \
  --region ap-south-1 \
  --query "KeyPairs[*].[KeyName,KeyPairId]" \
  --output table
```

Example

```text
------------------------------------------
|            DescribeKeyPairs            |
+--------------+-------------------------+
|  crdb-key    |  key-0153fd1adebe4d08e  |
|  patroni-key |  key-051083e1135b53304  |
+--------------+-------------------------+
```

---

## Step 4.2: Verify Key Pair in Singapore

```bash
aws ec2 describe-key-pairs \
  --region ap-southeast-1 \
  --query "KeyPairs[*].[KeyName,KeyPairId]" \
  --output table
```

If the output is empty, the key pair must be imported into the Singapore region before launching EC2 instances.

---

## Step 4.3: Verify the Public Key Exists on Your Local Machine

```bash
ls -l ~/.ssh
```

Look for files such as:

```text
id_rsa
id_rsa.pub
```

or

```text
crdb-key
crdb-key.pub
```

> **Note:** AWS stores only the **public key**. If you only have `crdb-key.pem`, 
AWS cannot recreate the public key from it. You must have the corresponding `.pub` file or create a new key pair.

---

## Step 4.4: Import the Public Key into Singapore

If your public key is `id_rsa.pub`:

```bash
aws ec2 import-key-pair \
  --region ap-southeast-1 \
  --key-name crdb-key \
  --public-key-material fileb://~/.ssh/id_rsa.pub
```

If your public key is `crdb-key.pub`:

```bash
aws ec2 import-key-pair \
  --region ap-southeast-1 \
  --key-name crdb-key \
  --public-key-material fileb://~/.ssh/crdb-key.pub
```

---

## Step 4.5: Verify the Import

```bash
aws ec2 describe-key-pairs \
  --region ap-southeast-1 \
  --query "KeyPairs[*].[KeyName,KeyPairId]" \
  --output table
```

Expected

```text
------------------------------------------
|            DescribeKeyPairs            |
+--------------+-------------------------+
|  crdb-key    |  key-xxxxxxxxxxxxxxxxx  |
+--------------+-------------------------+
```

---

## Step 4.6: Launch EC2 Instances Using the Imported Key

Now use the imported key when launching **Node5** and **Node6**.

Example:

```bash
aws ec2 run-instances \
  --image-id <AMI-ID> \
  --instance-type t3.medium \
  --key-name crdb-key \
  --subnet-id <SUBNET-ID> \
  --security-group-ids <SG-ID> \
  ...
```

---

### Updated Lab Flow

```
Step 1  Create VPC (10.20.0.0/16)
        │
Step 2  Create Subnets, IGW, Route Tables
        │
Step 3  Create Security Group
        │
Step 4  Verify & Import EC2 Key Pair (crdb-key)
        │
Step 5  Launch Node5 and Node6
        │
Step 6  Configure VPC Peering
        │
Step 7  Install CockroachDB
        │
Step 8  Configure systemd Service
        │
Step 9  Start CockroachDB
        │
Step 10 Verify Node5 and Node6 Joined the Existing Cluster
```
