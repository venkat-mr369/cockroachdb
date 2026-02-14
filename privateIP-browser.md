private IP won't open in browser directly. Here are 3 ways to access it:

---

## Option 1: SSH Tunnel through Bastion (Easiest)

From your local machine, run:

```bash
ssh -i paris-key.pem -L 8080:10.0.1.220:8080 ec2-user@BASTION_PUBLIC_IP
```

Now open browser on your laptop:
```
https://localhost:8080
```

Login with `max` / `max`. Done.

To tunnel all 3 nodes at once:
```bash
ssh -i paris-key.pem \
  -L 8080:10.0.1.220:8080 \
  -L 8081:10.0.2.43:8080 \
  -L 8082:10.0.3.241:8080 \
  ec2-user@BASTION_PUBLIC_IP
```

Then access:
- db1 → `https://localhost:8080`
- db2 → `https://localhost:8081`
- db3 → `https://localhost:8082`

---

## Option 2: AWS Systems Manager (SSM) — No Bastion Needed

### Step A: Attach SSM role to EC2
```bash
aws iam create-instance-profile --instance-profile-name paris-ssm-profile

aws iam add-role-to-instance-profile --instance-profile-name paris-ssm-profile --role-name AmazonSSMRoleForInstancesQuickSetup

aws ec2 associate-iam-instance-profile --instance-id paris-db1 --iam-instance-profile Name=paris-ssm-profile
```

### Step B: Install SSM plugin on your laptop
Download from: https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

### Step C: Port forward
```bash
aws ssm start-session \
  --target paris-db1 \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["10.0.1.220"],"portNumber":["8080"],"localPortNumber":["8080"]}'
```

Then open browser: `https://localhost:8080`

---

## Option 3: Application Load Balancer (ALB) — For Team Access

### Step A: Create ALB security group
```bash
aws ec2 create-security-group --group-name alb-sg-paris --description "ALB for CockroachDB UI" --vpc-id vpc-08d11b7a855ee1b41
```
Copy GroupId → replace `alb-sg-paris`
```bash
aws ec2 create-tags --resources alb-sg-paris --tags Key=Name,Value=alb-sg-paris
aws ec2 authorize-security-group-ingress --group-id alb-sg-paris --protocol tcp --port 443 --cidr YOUR_IP/32
```

Allow ALB to reach CockroachDB nodes:
```bash
aws ec2 authorize-security-group-ingress --group-id crdb-sg-paris --protocol tcp --port 8080 --source-group alb-sg-paris
```

### Step B: Create target group
```bash
aws elbv2 create-target-group \
  --name paris-crdb-tg \
  --protocol HTTPS \
  --port 8080 \
  --vpc-id vpc-08d11b7a855ee1b41 \
  --target-type ip \
  --health-check-path /health \
  --health-check-protocol HTTPS
```
Copy TargetGroupArn → replace `paris-crdb-tg-arn`

### Step C: Register targets
```bash
aws elbv2 register-targets --target-group-arn paris-crdb-tg-arn --targets Id=10.0.1.220,Port=8080 Id=10.0.2.43,Port=8080 Id=10.0.3.241,Port=8080
```

### Step D: Create ALB (needs public subnet)
```bash
aws elbv2 create-load-balancer \
  --name paris-crdb-alb \
  --subnets paris-subnet-public \
  --security-groups alb-sg-paris \
  --scheme internet-facing \
  --type application
```
Copy DNSName from output → use in browser

---

## Recommendation

| Method | Best For | Effort |
|--------|----------|--------|
| SSH Tunnel | Single developer, quick access | Easiest |
| SSM | No bastion, AWS native | Medium |
| ALB | Team access, permanent setup | More setup |

**Start with Option 1** — just one SSH command and you're in the browser.
