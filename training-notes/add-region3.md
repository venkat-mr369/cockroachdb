### Step 3: Create Security Groups

Create one security group in each region named **sg_cockroach**.

#### 3.1 Mumbai (ap-south-1)

``` bash
aws ec2 create-security-group \
  --region ap-south-1 \
  --group-name sg_cockroach \
  --description "CockroachDB Security Group" \
  --vpc-id <MUMBAI-VPC-ID>
```

Tag it:

``` bash
aws ec2 create-tags \
  --region ap-south-1 \
  --resources <MUMBAI-SG-ID> \
  --tags Key=Name,Value=sg_cockroach
```

#### 3.2 Singapore (ap-southeast-1)

``` bash
aws ec2 create-security-group \
  --region ap-southeast-1 \
  --group-name sg_cockroach \
  --description "CockroachDB Security Group" \
  --vpc-id <SINGAPORE-VPC-ID>
```

Tag it:

``` bash
aws ec2 create-tags \
  --region ap-southeast-1 \
  --resources <SINGAPORE-SG-ID> \
  --tags Key=Name,Value=sg_cockroach
```

### Required Inbound Rules

  Region        Protocol    Port Source
  ----------- ---------- ------- -----------------
  Mumbai             TCP      22 0.0.0.0/0 (Lab)
  Mumbai             TCP   26257 10.10.0.0/16
  Mumbai             TCP   26257 10.30.0.0/16
  Mumbai             TCP    8080 0.0.0.0/0
  Mumbai            ICMP     All 10.30.0.0/16
  Singapore          TCP      22 0.0.0.0/0 (Lab)
  Singapore          TCP   26257 10.10.0.0/16
  Singapore          TCP   26257 10.30.0.0/16
  Singapore          TCP    8080 0.0.0.0/0
  Singapore         ICMP     All 10.10.0.0/16

> Do **not** use `10.30.0.0/24`. Use the full Singapore VPC CIDR
> `10.30.0.0/16`.

### Verify

``` bash
aws ec2 describe-security-groups --region ap-south-1 --group-ids <MUMBAI-SG-ID>

aws ec2 describe-security-groups --region ap-southeast-1 --group-ids <SINGAPORE-SG-ID>
```
