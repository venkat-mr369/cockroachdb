### Step 5: Configure Inter-Region VPC Peering

#### Region-A (Mumbai)

-   Region: `ap-south-1`
-   CIDR: `10.10.0.0/16`

#### Region-B (Singapore)

-   Region: `ap-southeast-1`
-   CIDR: `10.30.0.0/16`

### 5.1 Create Peering

``` bash
aws ec2 create-vpc-peering-connection \
  --region ap-south-1 \
  --vpc-id <MUMBAI-VPC-ID> \
  --peer-vpc-id <SINGAPORE-VPC-ID> \
  --peer-region ap-southeast-1
```

Tag it:

``` bash
aws ec2 create-tags \
  --region ap-south-1 \
  --resources <PCX-ID> \
  --tags Key=Name,Value=Mumbai-Singapore-Peering
```

### 5.2 Accept Peering

``` bash
aws ec2 accept-vpc-peering-connection \
  --region ap-southeast-1 \
  --vpc-peering-connection-id <PCX-ID>
```

### 5.3 Add Routes

Mumbai:

``` bash
aws ec2 create-route \
  --region ap-south-1 \
  --route-table-id <MUMBAI-RTB-ID> \
  --destination-cidr-block 10.30.0.0/16 \
  --vpc-peering-connection-id <PCX-ID>
```

Singapore:

``` bash
aws ec2 create-route \
  --region ap-southeast-1 \
  --route-table-id <SINGAPORE-RTB-ID> \
  --destination-cidr-block 10.10.0.0/16 \
  --vpc-peering-connection-id <PCX-ID>
```

### 5.4 Verify Routes

Mumbai should contain:

-   10.10.0.0/16 → local
-   10.30.0.0/16 → PCX
-   0.0.0.0/0 → IGW

Singapore should contain:

-   10.30.0.0/16 → local
-   10.10.0.0/16 → PCX
-   0.0.0.0/0 → IGW

``` bash
aws ec2 describe-route-tables --region ap-south-1 --route-table-ids <MUMBAI-RTB-ID> --query "RouteTables[*].Routes[*].[DestinationCidrBlock,VpcPeeringConnectionId,State]" --output table

aws ec2 describe-route-tables --region ap-southeast-1 --route-table-ids <SINGAPORE-RTB-ID> --query "RouteTables[*].Routes[*].[DestinationCidrBlock,VpcPeeringConnectionId,State]" --output table
```

### 5.5 Connectivity Test

From Node1:

``` bash
ping 10.30.1.10
```

From Node5:

``` bash
ping 10.10.1.10
nc -zv 10.10.1.10 26257
```
