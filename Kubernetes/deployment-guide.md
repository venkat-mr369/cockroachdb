# CockroachDB Deployment & Testing Guide

## Prerequisites

- Kubernetes cluster (1.19+)
- kubectl configured to access your cluster
- At least 4 nodes with 8GB RAM each (or appropriate resource allocation)
- Default StorageClass configured for dynamic PV provisioning
- 400GB+ total storage available

## Quick Start - Complete Deployment

### Step 1: Deploy Everything

```bash
# Apply all resources in order
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-statefulset.yaml
kubectl apply -f 03-services.yaml

# Wait for pods to be running (this may take 2-3 minutes)
kubectl -n trading get pods -w

# You should see:
# cockroachdb-0   1/1   Running   0   2m
# cockroachdb-1   1/1   Running   0   2m
# cockroachdb-2   1/1   Running   0   2m
# cockroachdb-3   1/1   Running   0   2m
```

### Step 2: Initialize the Cluster

```bash
# Run the initialization job
kubectl apply -f 04-init-job.yaml

# Check initialization progress
kubectl -n trading logs -f job/cockroachdb-init

# Verify job completed successfully
kubectl -n trading get jobs
# Should show: cockroachdb-init   1/1   30s   2m
```

### Step 3: Verify Cluster Status

```bash
# Deploy client pod
kubectl apply -f 06-client-pod.yaml

# Wait for client pod
kubectl -n trading wait --for=condition=ready pod/cockroachdb-client

# Check cluster status
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach node status --insecure --host=cockroachdb-public:26257

# Expected output:
#  id |               address                |     sql_address          |  build  |            started_at            | is_live
# ----+--------------------------------------+--------------------------+---------+----------------------------------+---------
#   1 | cockroachdb-0.cockroachdb:26257      | cockroachdb-0.cockroachdb:26257  | v23.2.0 | 2024-02-08 10:00:00.000000+00:00 |  true
#   2 | cockroachdb-1.cockroachdb:26257      | cockroachdb-1.cockroachdb:26257  | v23.2.0 | 2024-02-08 10:00:10.000000+00:00 |  true
#   3 | cockroachdb-2.cockroachdb:26257      | cockroachdb-2.cockroachdb:26257  | v23.2.0 | 2024-02-08 10:00:20.000000+00:00 |  true
#   4 | cockroachdb-3.cockroachdb:26257      | cockroachdb-3.cockroachdb:26257  | v23.2.0 | 2024-02-08 10:00:30.000000+00:00 |  true
```

### Step 4: Load OpenAlgo Schema

```bash
# Copy schema file to client pod
kubectl -n trading cp 05-openalgo-schema.sql cockroachdb-client:/tmp/schema.sql

# Execute schema
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 < /tmp/schema.sql

# Verify database creation
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 -e "SHOW DATABASES;"

# Expected output:
#   database_name | owner | primary_region | secondary_region | regions | survival_goal
# ----------------+-------+----------------+------------------+---------+---------------
#   defaultdb     | root  | NULL           | NULL             | {}      | NULL
#   openalgo      | root  | NULL           | NULL             | {}      | NULL
#   postgres      | root  | NULL           | NULL             | {}      | NULL
#   system        | node  | NULL           | NULL             | {}      | NULL
```

## Access Methods

### 1. SQL Access via Client Pod

```bash
# Interactive SQL shell
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 --database=openalgo

# Run single query
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 \
  -e "SELECT * FROM instruments LIMIT 5;"
```

### 2. Admin UI Access

```bash
# Port forward to access Admin UI
kubectl -n trading port-forward cockroachdb-0 8080:8080

# Visit in browser: http://localhost:8080
# No authentication required (insecure mode)
```

### 3. Direct Pod Access

```bash
# Connect to specific pod
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure --database=openalgo
```

### 4. Application Connection String

For your OpenAlgo application:

```
# From within the cluster
postgresql://openalgo:trading123@cockroachdb-public.trading.svc.cluster.local:26257/openalgo?sslmode=disable

# If using external LoadBalancer (get external IP first)
kubectl -n trading get svc cockroachdb-external
# Then use: postgresql://openalgo:trading123@<EXTERNAL-IP>:26257/openalgo?sslmode=disable
```

## Testing the Deployment

### Test 1: Data Distribution

```bash
# Insert test data
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 <<EOF
USE openalgo;

-- Insert test orders
INSERT INTO orders (account_id, instrument_id, order_type, transaction_type, product_type, quantity, price, status)
SELECT 
    (SELECT id FROM accounts LIMIT 1),
    (SELECT id FROM instruments WHERE symbol = 'RELIANCE' LIMIT 1),
    'LIMIT',
    'BUY',
    'DELIVERY',
    generate_series,
    2500.00 + (random() * 100),
    'COMPLETE'
FROM generate_series(1, 1000);

-- Check range distribution
SHOW RANGES FROM TABLE orders;
EOF
```

### Test 2: Fault Tolerance

```bash
# Delete one pod to simulate node failure
kubectl -n trading delete pod cockroachdb-2

# Watch it recover
kubectl -n trading get pods -w

# Verify cluster still operational
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach node status --insecure --host=cockroachdb-public:26257

# Run a query to verify data still accessible
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 \
  -e "SELECT COUNT(*) FROM openalgo.orders;"
```

### Test 3: Performance Testing

```bash
# Run workload test
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach workload init bank \
  'postgresql://root@cockroachdb-public:26257?sslmode=disable'

# Run concurrent transactions
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach workload run bank \
  --duration=1m \
  --concurrency=10 \
  'postgresql://root@cockroachdb-public:26257?sslmode=disable'
```

## OpenAlgo Application Integration

### Python Example (using psycopg2)

```python
import psycopg2
from psycopg2.pool import ThreadedConnectionPool

# Connection pool for better performance
pool = ThreadedConnectionPool(
    minconn=5,
    maxconn=20,
    host='cockroachdb-public.trading.svc.cluster.local',
    port=26257,
    database='openalgo',
    user='openalgo',
    password='trading123',
    sslmode='disable'
)

def place_order(symbol, side, quantity, price):
    conn = pool.getconn()
    try:
        with conn.cursor() as cur:
            # Get instrument ID
            cur.execute(
                "SELECT id FROM instruments WHERE symbol = %s LIMIT 1",
                (symbol,)
            )
            instrument_id = cur.fetchone()[0]
            
            # Get account ID
            cur.execute("SELECT id FROM accounts LIMIT 1")
            account_id = cur.fetchone()[0]
            
            # Insert order
            cur.execute("""
                INSERT INTO orders 
                (account_id, instrument_id, order_type, transaction_type, 
                 product_type, quantity, price, status)
                VALUES (%s, %s, 'LIMIT', %s, 'DELIVERY', %s, %s, 'PENDING')
                RETURNING id
            """, (account_id, instrument_id, side, quantity, price))
            
            order_id = cur.fetchone()[0]
            conn.commit()
            return order_id
    finally:
        pool.putconn(conn)

# Place a test order
order_id = place_order('RELIANCE', 'BUY', 100, 2550.50)
print(f"Order placed: {order_id}")
```

### Node.js Example (using pg)

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: 'cockroachdb-public.trading.svc.cluster.local',
  port: 26257,
  database: 'openalgo',
  user: 'openalgo',
  password: 'trading123',
  ssl: false,
  max: 20,
  idleTimeoutMillis: 30000,
});

async function placeOrder(symbol, side, quantity, price) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    
    // Get instrument ID
    const instrumentResult = await client.query(
      'SELECT id FROM instruments WHERE symbol = $1 LIMIT 1',
      [symbol]
    );
    const instrumentId = instrumentResult.rows[0].id;
    
    // Get account ID
    const accountResult = await client.query(
      'SELECT id FROM accounts LIMIT 1'
    );
    const accountId = accountResult.rows[0].id;
    
    // Insert order
    const orderResult = await client.query(`
      INSERT INTO orders 
      (account_id, instrument_id, order_type, transaction_type, 
       product_type, quantity, price, status)
      VALUES ($1, $2, 'LIMIT', $3, 'DELIVERY', $4, $5, 'PENDING')
      RETURNING id
    `, [accountId, instrumentId, side, quantity, price]);
    
    await client.query('COMMIT');
    return orderResult.rows[0].id;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
}

// Place test order
placeOrder('RELIANCE', 'BUY', 100, 2550.50)
  .then(orderId => console.log(`Order placed: ${orderId}`))
  .catch(err => console.error(err));
```

## Monitoring

### Check Cluster Health

```bash
# Node status
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach node status --insecure

# Database list
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e "SHOW DATABASES;"

# Table statistics
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -d openalgo -e "SHOW TABLES;"

# Replication status
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach node status --ranges --insecure
```

### Admin UI Metrics

Access via port-forward and check:
- **Overview**: Cluster health, node count, capacity
- **Metrics**: QPS, latency, storage usage
- **Databases**: Table sizes, range distribution
- **SQL Activity**: Active queries, slow queries
- **Network**: Inter-node traffic

### Resource Usage

```bash
# Pod resource usage
kubectl -n trading top pods

# PVC usage
kubectl -n trading get pvc

# Describe pod for detailed info
kubectl -n trading describe pod cockroachdb-0
```

## Scaling Operations

### Scale Up (Add Nodes)

```bash
# Scale to 6 nodes
kubectl -n trading scale statefulset cockroachdb --replicas=6

# Watch new pods come up
kubectl -n trading get pods -w

# Verify cluster recognized new nodes
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach node status --insecure
```

### Scale Down (Remove Nodes)

```bash
# First, decommission the node
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach node decommission 4 --insecure --host=cockroachdb-public:26257

# Wait for decommission to complete
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach node status --insecure

# Then scale down
kubectl -n trading scale statefulset cockroachdb --replicas=3
```

## Backup & Restore

### Manual Backup

```bash
# Full database backup
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "BACKUP DATABASE openalgo TO 'nodelocal://1/backups/openalgo-$(date +%Y%m%d)';"

# Table backup
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "BACKUP TABLE openalgo.orders TO 'nodelocal://1/backups/orders-$(date +%Y%m%d)';"
```

### Scheduled Backups (Production)

```bash
# Create backup schedule (requires enterprise license or trial)
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure <<EOF
CREATE SCHEDULE openalgo_daily_backup
FOR BACKUP DATABASE openalgo
INTO 's3://my-backup-bucket/openalgo?AWS_ACCESS_KEY_ID=xxx&AWS_SECRET_ACCESS_KEY=yyy'
RECURRING '@daily'
WITH SCHEDULE OPTIONS first_run = 'now';
EOF
```

### Restore

```bash
# Restore database
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "RESTORE DATABASE openalgo FROM 'nodelocal://1/backups/openalgo-20240208';"
```

## Troubleshooting

### Pod Won't Start

```bash
# Check pod events
kubectl -n trading describe pod cockroachdb-0

# Check logs
kubectl -n trading logs cockroachdb-0

# Common issues:
# - PVC provisioning failed (check storage class)
# - Resource limits too low
# - DNS resolution issues
```

### Cluster Won't Initialize

```bash
# Check init job logs
kubectl -n trading logs job/cockroachdb-init

# Manually initialize
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach init --insecure --host=cockroachdb-0.cockroachdb:26257
```

### Connection Issues

```bash
# Test DNS resolution
kubectl -n trading exec -it cockroachdb-client -- \
  nslookup cockroachdb-public

# Test connectivity
kubectl -n trading exec -it cockroachdb-client -- \
  nc -zv cockroachdb-public 26257

# Check service endpoints
kubectl -n trading get endpoints cockroachdb
```

### Performance Issues

```bash
# Check for hot ranges
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e "SELECT * FROM crdb_internal.ranges_no_leases LIMIT 10;"

# Analyze slow queries via Admin UI
# Or via SQL:
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "SELECT * FROM crdb_internal.node_statement_statistics ORDER BY mean_latency DESC LIMIT 10;"
```

## Cleanup

```bash
# Delete all resources
kubectl delete -f 06-client-pod.yaml
kubectl delete -f 04-init-job.yaml
kubectl delete -f 03-services.yaml
kubectl delete -f 02-statefulset.yaml

# Delete PVCs (warning: this deletes all data!)
kubectl -n trading delete pvc -l app=cockroachdb

# Delete namespace
kubectl delete -f 01-namespace.yaml
```

## Production Recommendations

### 1. Enable TLS
- Generate certificates using `cockroach cert`
- Create Kubernetes secrets
- Update StatefulSet to use secure mode

### 2. Configure Resource Limits
- Adjust CPU/memory based on workload
- Monitor and tune cache settings
- Use node affinity for hardware optimization

### 3. Multi-Zone Deployment
- Use topology spread constraints
- Configure zone preferences
- Enable geo-partitioning for compliance

### 4. Monitoring & Alerting
- Deploy Prometheus & Grafana
- Set up alerts for node failures
- Monitor slow queries and hot ranges

### 5. Backup Strategy
- Automated scheduled backups to S3/GCS
- Test restore procedures regularly
- Maintain backup retention policy

### 6. Security
- Enable RBAC
- Use network policies
- Rotate credentials regularly
- Enable audit logging

## Next Steps

1. **Load Test**: Use realistic trading workloads
2. **Tune Performance**: Adjust based on query patterns
3. **Implement HA**: Configure for your availability requirements
4. **Monitor**: Set up comprehensive monitoring
5. **Document**: Create runbooks for operations team

## Additional Resources

- CockroachDB Documentation: https://www.cockroachlabs.com/docs/
- Kubernetes StatefulSets: https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/
- Performance Tuning: https://www.cockroachlabs.com/docs/stable/performance-best-practices-overview.html
