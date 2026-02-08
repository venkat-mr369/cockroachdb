# CockroachDB on Kubernetes for Trading Applications (OpenAlgo)

## Introduction

CockroachDB is a distributed SQL database designed for cloud-native applications, offering:
- **Horizontal scalability** - Add nodes without downtime
- **High availability** - Survives node, zone, and region failures
- **Strong consistency** - ACID transactions across distributed data
- **PostgreSQL compatibility** - Use existing PostgreSQL tools and drivers

For trading applications like OpenAlgo, CockroachDB provides:
- **Low-latency transactions** - Critical for order execution
- **Data consistency** - No lost or duplicate trades
- **Geo-distribution** - Deploy close to exchanges globally
- **Resilience** - No single point of failure

## Architecture Overview: 4-Node Cluster

```
┌─────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                      │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ CockroachDB│ │ CockroachDB│ │ CockroachDB│ │ CockroachDB│   │
│  │  Node 0   │ │  Node 1   │ │  Node 2   │ │  Node 3   │   │
│  │           │ │           │ │           │ │           │   │
│  │ PV: 100GB │ │ PV: 100GB │ │ PV: 100GB │ │ PV: 100GB │   │
│  └─────┬─────┘ └─────┬─────┘ └─────┬─────┘ └─────┬─────┘   │
│        │             │             │             │           │
│        └─────────────┴─────────────┴─────────────┘           │
│                  Internal Gossip Protocol                     │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │            Headless Service (Cluster)                   │  │
│  │      cockroachdb-0.cockroachdb:26257                   │  │
│  │      cockroachdb-1.cockroachdb:26257                   │  │
│  │      cockroachdb-2.cockroachdb:26257                   │  │
│  │      cockroachdb-3.cockroachdb:26257                   │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌────────────────────────────────────────────────────────┐  │
│  │         Public Service (Load Balanced)                  │  │
│  │        cockroachdb-public:26257 (SQL)                  │  │
│  │        cockroachdb-public:8080 (Admin UI)              │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Replication & Fault Tolerance

With 4 nodes and default replication factor of 3:
- Each range is replicated 3 times
- Cluster survives loss of 1 node (maintains quorum: 2/3)
- Automatic rebalancing when nodes fail or are added

## Why 4 Nodes?

- **Odd vs Even**: While Raft consensus typically prefers odd numbers (3, 5), 4 nodes is acceptable
- **Performance**: Better throughput distribution than 3 nodes
- **Upgrade Path**: Easy to scale to 5 or 6 nodes for multi-region
- **Cost/Performance Balance**: Good for medium-scale trading systems

## OpenAlgo Trading Application Context

OpenAlgo is an algorithmic trading platform that requires:
- **Order Management**: Fast writes for order submission
- **Position Tracking**: Consistent reads for portfolio state
- **Trade History**: Time-series data for analysis
- **Strategy State**: Transactional updates for trading logic
- **Market Data Cache**: High-throughput reads

CockroachDB handles all these workloads in a single database with strong consistency.

## Deployment Components

### 1. Namespace
Isolate CockroachDB resources

### 2. StatefulSet
- Manages 4 CockroachDB pods
- Stable network identities (cockroachdb-0 through cockroachdb-3)
- Persistent storage for each pod

### 3. Services
- **Headless Service**: For inter-node communication
- **Public Service**: For client connections and Admin UI

### 4. PersistentVolumeClaims
- Automatically provisioned via StatefulSet
- 100GB per node (adjustable based on data volume)

### 5. ConfigMap
- CockroachDB configuration
- Cluster settings

### 6. RBAC
- ServiceAccount for pod operations
- Roles for cluster initialization

## Key Kubernetes Concepts

### StatefulSet vs Deployment
CockroachDB uses StatefulSet because:
- Each pod needs a stable hostname
- Each pod needs dedicated persistent storage
- Ordered deployment and scaling
- DNS records like `cockroachdb-0.cockroachdb.default.svc.cluster.local`

### Headless Service
- `clusterIP: None`
- Creates DNS records for each pod
- Enables peer discovery via DNS
- CockroachDB nodes use this to find each other

### Init Containers
- Used to initialize the cluster
- Runs `cockroach init` on first pod
- Only needs to run once

## Next Steps

See the accompanying YAML files for:
1. `namespace.yaml` - Namespace creation
2. `statefulset.yaml` - Main CockroachDB deployment
3. `services.yaml` - Network access configuration
4. `init-job.yaml` - Cluster initialization
5. `openalgo-schema.sql` - Trading database schema
6. `client-pod.yaml` - Testing and administration

## Monitoring and Operations

### Health Checks
```bash
# Check cluster status
kubectl exec -it cockroachdb-0 -- ./cockroach node status --insecure

# Check database
kubectl exec -it cockroachdb-0 -- ./cockroach sql --insecure -e "SHOW DATABASES;"
```

### Admin UI
Access via port-forward:
```bash
kubectl port-forward cockroachdb-0 8080:8080
# Visit http://localhost:8080
```

### Scaling
```bash
# Scale to 6 nodes
kubectl scale statefulset cockroachdb --replicas=6

# Scale down to 3 nodes (ensure data is replicated first)
kubectl scale statefulset cockroachdb --replicas=3
```

## Performance Tuning for Trading

### Connection Pooling
OpenAlgo should use connection pooling:
```python
# Example with SQLAlchemy
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    'postgresql://root@cockroachdb-public:26257/openalgo?sslmode=disable',
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=True
)
```

### Batch Inserts
For high-frequency trade data:
```sql
-- Batch insert trades
INSERT INTO trades (symbol, side, quantity, price, timestamp)
VALUES 
    ('AAPL', 'BUY', 100, 150.50, NOW()),
    ('GOOGL', 'SELL', 50, 2800.00, NOW()),
    ('MSFT', 'BUY', 75, 300.25, NOW());
```

### Index Strategy
```sql
-- Composite indexes for common queries
CREATE INDEX idx_trades_symbol_timestamp ON trades (symbol, timestamp DESC);
CREATE INDEX idx_orders_status_created ON orders (status, created_at);
```

## Backup and Recovery

### Scheduled Backups
```sql
-- Create backup schedule
CREATE SCHEDULE trading_backup
FOR BACKUP INTO 's3://my-bucket/cockroach-backups?AWS_ACCESS_KEY_ID=xxx&AWS_SECRET_ACCESS_KEY=yyy'
RECURRING '@daily'
WITH SCHEDULE OPTIONS first_run = 'now';
```

### Point-in-Time Recovery
```sql
-- Restore to specific time
RESTORE DATABASE openalgo FROM 's3://my-bucket/cockroach-backups'
AS OF SYSTEM TIME '2024-02-08 10:00:00';
```

## Security Considerations

### Production Deployment
For production, enable TLS:
1. Generate certificates
2. Create Kubernetes secrets
3. Mount certificates in pods
4. Configure secure connections

### Network Policies
Restrict access to CockroachDB:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cockroachdb-netpol
spec:
  podSelector:
    matchLabels:
      app: cockroachdb
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: openalgo
    ports:
    - protocol: TCP
      port: 26257
```

## Common Issues and Solutions

### Pod Not Starting
- Check PVC provisioning: `kubectl get pvc`
- Review logs: `kubectl logs cockroachdb-0`
- Verify resource limits aren't too restrictive

### Connection Refused
- Ensure service is running: `kubectl get svc`
- Check cluster initialization: `kubectl get jobs`
- Verify network policies

### Performance Issues
- Monitor Admin UI for hot ranges
- Check connection pool settings
- Review query plans: `EXPLAIN ANALYZE`
- Consider adding indexes

## Resources

- **CPU**: 2 cores per node minimum, 4+ recommended
- **Memory**: 4GB per node minimum, 8GB+ recommended
- **Storage**: SSD-backed PVs, size based on data volume
- **Network**: Low-latency network for inter-node communication
