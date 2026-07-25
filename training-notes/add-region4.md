### Step 4: Launch EC2 Instances (Node5 & Node6) using AWS CLI

Before running the commands, get the required IDs.

### 4.1 Find the Ubuntu 24.04 AMI

```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
            "Name=state,Values=available" \
  --query "Images | sort_by(@,&CreationDate)[-1].ImageId" \
  --output text
```

Example output:

```text
ami-0abc123456789def0
```

Save this as `<AMI-ID>`.

---

### 4.2 Launch Node5

Replace the placeholders with your values.

```bash
aws ec2 run-instances \
  --image-id <AMI-ID> \
  --instance-type t3.medium \
  --key-name <KEYPAIR-NAME> \
  --subnet-id <SUBNET1-ID> \
  --private-ip-address 10.20.1.10 \
  --security-group-ids <SG-ID> \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=crdb-node5}]'
```

---

### 4.3 Launch Node6

```bash
aws ec2 run-instances \
  --image-id <AMI-ID> \
  --instance-type t3.medium \
  --key-name <KEYPAIR-NAME> \
  --subnet-id <SUBNET2-ID> \
  --private-ip-address 10.20.2.10 \
  --security-group-ids <SG-ID> \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":30,"VolumeType":"gp3"}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=crdb-node6}]'
```

---

### 4.4 Verify the Instances

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=crdb-node5,crdb-node6" \
  --query "Reservations[*].Instances[*].[Tags[0].Value,PrivateIpAddress,State.Name]" \
  --output table
```

Expected output:

```text
-------------------------------------------------------
| DescribeInstances                                   |
+------------+-------------+------------+
| crdb-node5 | 10.20.1.10  | running    |
| crdb-node6 | 10.20.2.10  | running    |
+------------+-------------+------------+
```

---

### 4.5 Get Public IP Addresses

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=crdb-node5,crdb-node6" \
  --query "Reservations[*].Instances[*].[Tags[0].Value,PublicIpAddress]" \
  --output table
```

---

### Lab Status

At this point you have:

* ✅ Region-B VPC created
* ✅ Subnets created
* ✅ Internet Gateway configured
* ✅ Route Table configured
* ✅ Security Group created
* ✅ Node5 EC2 instance running
* ✅ Node6 EC2 instance running

