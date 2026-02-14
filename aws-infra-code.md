Here's the complete command flow — copy-paste ready, just replace the placeholder IDs after each create command.

---

## Step 1: Create VPC

```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --region eu-west-3
```
Copy VpcId → replace `vpc-paris` everywhere below

```bash
aws ec2 create-tags --resources vpc-paris --tags Key=Name,Value=vpc-paris
aws ec2 modify-vpc-attribute --vpc-id vpc-paris --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id vpc-paris --enable-dns-support
```

---

## Step 2: Create Subnets

```bash
aws ec2 create-subnet --vpc-id vpc-paris --cidr-block 10.0.1.0/24 --availability-zone eu-west-3a
```
Copy SubnetId → replace `paris-subnet1`
```bash
aws ec2 create-tags --resources paris-subnet1 --tags Key=Name,Value=paris-subnet1
```

```bash
aws ec2 create-subnet --vpc-id vpc-paris --cidr-block 10.0.2.0/24 --availability-zone eu-west-3b
```
Copy SubnetId → replace `paris-subnet2`
```bash
aws ec2 create-tags --resources paris-subnet2 --tags Key=Name,Value=paris-subnet2
```

```bash
aws ec2 create-subnet --vpc-id vpc-paris --cidr-block 10.0.3.0/24 --availability-zone eu-west-3c
```
Copy SubnetId → replace `paris-subnet3`
```bash
aws ec2 create-tags --resources paris-subnet3 --tags Key=Name,Value=paris-subnet3
```

```bash
aws ec2 create-subnet --vpc-id vpc-paris --cidr-block 10.0.100.0/24 --availability-zone eu-west-3a
```
Copy SubnetId → replace `paris-subnet-public`
```bash
aws ec2 create-tags --resources paris-subnet-public --tags Key=Name,Value=paris-subnet-public
aws ec2 modify-subnet-attribute --subnet-id paris-subnet-public --map-public-ip-on-launch
```

---

## Step 3: Internet Gateway

```bash
aws ec2 create-internet-gateway
```
Copy InternetGatewayId → replace `internet-gw-paris`
```bash
aws ec2 create-tags --resources internet-gw-paris --tags Key=Name,Value=internet-gw-paris
aws ec2 attach-internet-gateway --internet-gateway-id internet-gw-paris --vpc-id vpc-paris
```

---

## Step 4: Route Tables

```bash
aws ec2 create-route-table --vpc-id vpc-paris
```
Copy RouteTableId → replace `public-rt-paris`
```bash
aws ec2 create-tags --resources public-rt-paris --tags Key=Name,Value=public-rt-paris
aws ec2 create-route --route-table-id public-rt-paris --destination-cidr-block 0.0.0.0/0 --gateway-id internet-gw-paris
aws ec2 associate-route-table --route-table-id public-rt-paris --subnet-id paris-subnet-public
```

```bash
aws ec2 create-route-table --vpc-id vpc-paris
```
Copy RouteTableId → replace `private-rt-paris`
```bash
aws ec2 create-tags --resources private-rt-paris --tags Key=Name,Value=private-rt-paris
aws ec2 associate-route-table --route-table-id private-rt-paris --subnet-id paris-subnet1
aws ec2 associate-route-table --route-table-id private-rt-paris --subnet-id paris-subnet2
aws ec2 associate-route-table --route-table-id private-rt-paris --subnet-id paris-subnet3
```

---

## Step 5: NAT Gateway + Elastic IP

```bash
aws ec2 allocate-address --domain vpc
```
Copy AllocationId → replace `eip-paris`
```bash
aws ec2 create-tags --resources eip-paris --tags Key=Name,Value=eip-paris
aws ec2 create-nat-gateway --subnet-id paris-subnet-public --allocation-id eip-paris
```
Copy NatGatewayId → replace `nat-gw-paris`
```bash
aws ec2 create-tags --resources nat-gw-paris --tags Key=Name,Value=nat-gw-paris
aws ec2 wait nat-gateway-available --nat-gateway-ids nat-gw-paris
aws ec2 create-route --route-table-id private-rt-paris --destination-cidr-block 0.0.0.0/0 --nat-gateway-id nat-gw-paris
```

---

## Step 6: Security Groups

```bash
aws ec2 create-security-group --group-name crdb-sg-paris --description "CockroachDB nodes" --vpc-id vpc-paris
```
Copy GroupId → replace `crdb-sg-paris`
```bash
aws ec2 create-tags --resources crdb-sg-paris --tags Key=Name,Value=crdb-sg-paris
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris --protocol tcp --port 26257 --cidr 10.0.0.0/16
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris --protocol tcp --port 8080 --cidr 10.0.0.0/16
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris --protocol tcp --port 22 --cidr 10.0.0.0/16
```

```bash
aws ec2 create-security-group --group-name bastion-sg-paris --description "Bastion SSH" --vpc-id vpc-paris
```
Copy GroupId → replace `bastion-sg-paris`
```bash
aws ec2 create-tags --resources bastion-sg-paris --tags Key=Name,Value=bastion-sg-paris
aws ec2 authorize-security-group-ingress --group-id bastion-sg-paris --protocol tcp --port 22 --cidr YOUR_IP/32
```

---

## Step 7: Key Pair

```bash
aws ec2 create-key-pair --key-name paris-key --query 'KeyMaterial' --output text > paris-key.pem
chmod 400 paris-key.pem
```

---

## Step 8: Get AMI & Launch Instances

```bash
aws ec2 describe-images --owners 099720109477 --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" "Name=state,Values=available" --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' --output text
```
Copy AMI ID → replace `ami-paris`

```bash
aws ec2 run-instances --image-id ami-paris --instance-type t3.medium --key-name paris-key --subnet-id paris-subnet1 --private-ip-address 10.0.1.10 --security-group-ids crdb-sg-paris
```
Copy InstanceId → replace `paris-db1`
```bash
aws ec2 create-tags --resources paris-db1 --tags Key=Name,Value=paris-db1
```

```bash
aws ec2 run-instances --image-id ami-paris --instance-type t3.medium --key-name paris-key --subnet-id paris-subnet2 --private-ip-address 10.0.2.10 --security-group-ids crdb-sg-paris
```
Copy InstanceId → replace `paris-db2`
```bash
aws ec2 create-tags --resources paris-db2 --tags Key=Name,Value=paris-db2
```

```bash
aws ec2 run-instances --image-id ami-paris --instance-type t3.medium --key-name paris-key --subnet-id paris-subnet3 --private-ip-address 10.0.3.10 --security-group-ids crdb-sg-paris
```
Copy InstanceId → replace `paris-db3`
```bash
aws ec2 create-tags --resources paris-db3 --tags Key=Name,Value=paris-db3
```

```bash
aws ec2 run-instances --image-id ami-paris --instance-type t3.micro --key-name paris-key --subnet-id paris-subnet-public --security-group-ids bastion-sg-paris --associate-public-ip-address
```
Copy InstanceId → replace `paris-bastion`
```bash
aws ec2 create-tags --resources paris-bastion --tags Key=Name,Value=paris-bastion
```

---

## Step 9: Get Bastion IP

```bash
aws ec2 describe-instances --instance-ids paris-bastion --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

---

## Step 10: Test

```bash
eval "$(ssh-agent -s)"
ssh-add paris-key.pem
ssh -A -i paris-key.pem ubuntu@BASTION_IP
ssh ubuntu@10.0.1.10
curl https://www.google.com
ping -c 3 google.com
```

---

## Cleanup

```bash
aws ec2 terminate-instances --instance-ids paris-db1 paris-db2 paris-db3 paris-bastion
aws ec2 wait instance-terminated --instance-ids paris-db1 paris-db2 paris-db3 paris-bastion
aws ec2 delete-nat-gateway --nat-gateway-id nat-gw-paris
sleep 60
aws ec2 release-address --allocation-id eip-paris
aws ec2 detach-internet-gateway --internet-gateway-id internet-gw-paris --vpc-id vpc-paris
aws ec2 delete-internet-gateway --internet-gateway-id internet-gw-paris
aws ec2 delete-subnet --subnet-id paris-subnet1
aws ec2 delete-subnet --subnet-id paris-subnet2
aws ec2 delete-subnet --subnet-id paris-subnet3
aws ec2 delete-subnet --subnet-id paris-subnet-public
aws ec2 delete-route-table --route-table-id public-rt-paris
aws ec2 delete-route-table --route-table-id private-rt-paris
aws ec2 delete-security-group --group-id crdb-sg-paris
aws ec2 delete-security-group --group-id bastion-sg-paris
aws ec2 delete-vpc --vpc-id vpc-paris
aws ec2 delete-key-pair --key-name paris-key
rm paris-key.pem
```
