### AWS CLI Lab – Part 3

### Create Key Pair and Launch Three Ubuntu EC2 Instances

> **Prerequisites**
>
> Complete **Part 1** and **Part 2**.
>
> Required variables:
>
> * `VPC_ID`
> * `SUBNET1`
> * `SUBNET2`
> * `SUBNET3`
> * `SG_ID`

---

## Step 23: Find Ubuntu 24.04 LTS AMI

```bash
aws ec2 describe-images \
  --owners 099720109477 \
  --filters \
  "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
  "Name=architecture,Values=x86_64" \
  "Name=virtualization-type,Values=hvm" \
  --query "Images | sort_by(@,&CreationDate)[-1].ImageId" \
  --output text \
  --region ap-south-1
```

Example:

```text
ami-xxxxxxxxxxxxxxxxx
```

Save it.

```bash
export AMI_ID=ami-xxxxxxxxxxxxxxxxx
```

Verify

```bash
echo $AMI_ID
```

---

## Step 24: Import/Create Key Pair

If you already have a public key:

```bash
aws ec2 import-key-pair \
  --key-name crdb-key \
  --public-key-material fileb://~/.ssh/id_rsa.pub
```

Verify

```bash
aws ec2 describe-key-pairs \
  --key-names crdb-key
```

---

## Step 25: Launch Node-1

```bash
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.small \
  --key-name crdb-key \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET1 \
  --private-ip-address 10.10.1.10 \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=crdb-node1}]'
```

Save the Instance ID.

```bash
export NODE1_INSTANCE=i-xxxxxxxxxxxxxxxxx
```

---

## Step 26: Launch Node-2

```bash
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.small \
  --key-name crdb-key \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET2 \
  --private-ip-address 10.10.2.10 \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=crdb-node2}]'
```

Save the Instance ID.

```bash
export NODE2_INSTANCE=i-xxxxxxxxxxxxxxxxx
```

---

## Step 27: Launch Node-3

```bash
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.small \
  --key-name crdb-key \
  --security-group-ids $SG_ID \
  --subnet-id $SUBNET3 \
  --private-ip-address 10.10.3.10 \
  --associate-public-ip-address \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":20,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=crdb-node3}]'
```

Save the Instance ID.

```bash
export NODE3_INSTANCE=i-xxxxxxxxxxxxxxxxx
```

---

## Step 28: Wait for Instances

```bash
aws ec2 wait instance-running \
  --instance-ids \
  $NODE1_INSTANCE \
  $NODE2_INSTANCE \
  $NODE3_INSTANCE
```

---

## Step 29: Verify Instances

```bash
aws ec2 describe-instances \
  --instance-ids \
  $NODE1_INSTANCE \
  $NODE2_INSTANCE \
  $NODE3_INSTANCE \
  --query "Reservations[].Instances[].{Name:Tags[?Key=='Name']|[0].Value,State:State.Name,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,AZ:Placement.AvailabilityZone}" \
  --output table
```

Expected

```text
-----------------------------------------------
| Name        | State   | PrivateIP | PublicIP |
-----------------------------------------------
| crdb-node1  | running |10.10.1.10 | xx.xx.xx.xx |
| crdb-node2  | running |10.10.2.10 | xx.xx.xx.xx |
| crdb-node3  | running |10.10.3.10 | xx.xx.xx.xx |
-----------------------------------------------
```

---

## Step 30: Retrieve Public IPs

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=crdb-node*" \
  --query "Reservations[].Instances[].{Name:Tags[0].Value,PublicIP:PublicIpAddress}" \
  --output table
```

---

## Step 31: SSH to Node-1

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<NODE1_PUBLIC_IP>
```

Verify

```bash
hostname

hostname -I
```

Expected

```text
crdb-node1

10.10.1.10
```

---

## Step 32: Verify Node Connectivity

From **Node-1**:

```bash
ping 10.10.2.10
```

```bash
ping 10.10.3.10
```

Both should respond successfully.

---

## End of Part 3

You now have:

* ✅ Ubuntu 24.04 LTS AMI
* ✅ AWS Key Pair (`crdb-key`)
* ✅ Three EC2 instances
* ✅ Fixed private IPs

  * Node1 → `10.10.1.10`
  * Node2 → `10.10.2.10`
  * Node3 → `10.10.3.10`
* ✅ Public IPs assigned
* ✅ SSH connectivity
* ✅ Inter-node network connectivity verified


