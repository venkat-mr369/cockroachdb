### Step 3: Create Security Group

#### 3.1 Create the Security Group

```bash
aws ec2 create-security-group \
  --group-name crdb-sg \
  --description "CockroachDB Security Group" \
  --vpc-id <VPC-ID>
```

Example output:

```json
{
    "GroupId": "sg-0123456789abcdef0"
}
```

Save the **GroupId** (for example, `sg-0123456789abcdef0`).

---

#### 3.2 Allow SSH (Port 22)

> For a production environment, replace `0.0.0.0/0` with your office or VPN public IP.

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <SG-ID> \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

---

#### 3.3 Allow CockroachDB SQL Port (26257)

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <SG-ID> \
  --protocol tcp \
  --port 26257 \
  --cidr 10.10.0.0/16
```

Allow Region-B VPC as well:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <SG-ID> \
  --protocol tcp \
  --port 26257 \
  --cidr 10.30.0.0/16
```

---

#### 3.4 Allow Admin UI (8080)

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <SG-ID> \
  --protocol tcp \
  --port 8080 \
  --cidr 10.10.0.0/16
```

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <SG-ID> \
  --protocol tcp \
  --port 8080 \
  --cidr 10.30.0.0/16
```

---

#### 3.5 Allow All Traffic Between CockroachDB Nodes

This allows all protocols between nodes in both VPCs.

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <SG-ID> \
  --protocol -1 \
  --cidr 10.10.0.0/16
```

```bash
aws ec2 authorize-security-group-ingress \
  --group-id <SG-ID> \
  --protocol -1 \
  --cidr 10.30.0.0/16
```

---

#### 3.6 Verify the Security Group Rules

```bash
aws ec2 describe-security-groups \
  --group-ids <SG-ID>
```

### Expected Rules

| Protocol | Port  | Source                                |
| -------- | ----- | ------------------------------------- |
| TCP      | 22    | Your IP (or `0.0.0.0/0` for lab only) |
| TCP      | 26257 | `10.10.0.0/16`                        |
| TCP      | 26257 | `10.30.0.0/16`                        |
| TCP      | 8080  | `10.10.0.0/16`                        |
| TCP      | 8080  | `10.30.0.0/16`                        |
| All      | All   | `10.30.0.0/16`                        |
| All      | All   | `10.30.0.0/16`                        |

#### Next Step

**Step 4:** Launch **Node5** and **Node6** EC2 instances using the AWS CLI with:

* Ubuntu 24.04 AMI
* `t3.medium` (or your preferred instance type)
* Static private IPs (`10.20.1.10` and `10.20.2.10`)
* The security group created above
* Your existing EC2 key pair
