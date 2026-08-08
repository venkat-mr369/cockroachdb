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
```text
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
```
> Do **not** use `10.30.0.0/24`. Use the full Singapore VPC CIDR
> `10.30.0.0/16`.

Add TCP 26257 for Singapore VPC (10.30.0.0/16)
```
aws ec2 authorize-security-group-ingress \
    --group-id sg-0fe5b9174d0eb03cf \
    --protocol tcp \
    --port 26257 \
    --cidr 10.30.0.0/16 \
    --region ap-southeast-1
```
Add ICMP for Singapore VPC (10.30.0.0/16)
```
aws ec2 authorize-security-group-ingress \
    --group-id sg-0fe5b9174d0eb03cf \
    --protocol icmp \
    --port -1 \
    --cidr 10.30.0.0/16 \
    --region ap-southeast-1
```
Verify the rules

```
aws ec2 describe-security-groups \
    --group-ids sg-0fe5b9174d0eb03cf \
    --region ap-southeast-1
```

### Verify

``` bash
aws ec2 describe-security-groups --region ap-south-1 --group-ids <MUMBAI-SG-ID>

aws ec2 describe-security-groups --region ap-southeast-1 --group-ids <SINGAPORE-SG-ID>
```
