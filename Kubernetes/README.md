# CockroachDB on Kubernetes for OpenAlgo Trading Platform

A production-ready deployment of a 4-node CockroachDB cluster on Kubernetes, optimized for algorithmic trading applications like OpenAlgo.

## 📁 Files Overview

```
.
├── README.md                           # This file
├── cockroachdb-k8s-trading-guide.md   # Comprehensive architecture & design guide
├── deployment-guide.md                 # Step-by-step deployment and operations
├── 01-namespace.yaml                   # Kubernetes namespace
├── 02-statefulset.yaml                 # CockroachDB StatefulSet (4 nodes)
├── 03-services.yaml                    # Headless & public services
├── 04-init-job.yaml                    # Cluster initialization job
├── 05-openalgo-schema.sql             # OpenAlgo trading database schema
└── 06-client-pod.yaml                  # Admin/testing client pod
```

## 🚀 Quick Start

Deploy the entire cluster in 5 minutes:

```bash
# 1. Create namespace and deploy CockroachDB
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-statefulset.yaml
kubectl apply -f 03-services.yaml

# 2. Wait for pods (2-3 minutes)
kubectl -n trading get pods -w

# 3. Initialize cluster and create database
kubectl apply -f 04-init-job.yaml

# 4. Deploy client pod
kubectl apply -f 06-client-pod.yaml

# 5. Load OpenAlgo schema
kubectl -n trading cp 05-openalgo-schema.sql cockroachdb-client:/tmp/
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 -f /tmp/05-openalgo-schema.sql
```

## 🎯 Architecture Highlights

### Cluster Configuration
- **4 nodes** for optimal performance and fault tolerance
- **Replication factor 3** - survives 1 node failure
- **StatefulSet** for stable network identities
- **100GB** persistent storage per node (SSD recommended)

### Why CockroachDB for Trading?
- ✅ **ACID transactions** - No lost or duplicate trades
- ✅ **Low latency** - Optimized for high-frequency operations
- ✅ **High availability** - Zero downtime during node failures
- ✅ **Horizontal scaling** - Add nodes without downtime
- ✅ **PostgreSQL compatible** - Use existing tools and libraries

### OpenAlgo Integration
The schema includes tables for:
- **Orders & Trades** - Real-time order management
- **Positions** - Current and historical positions with P&L
- **Market Data** - Tick data and OHLC candles
- **Strategies** - Algorithm definitions and state
- **Risk Management** - Limits and daily tracking
- **Audit Logs** - Complete compliance trail

## 📊 Database Schema

The OpenAlgo schema (`05-openalgo-schema.sql`) includes:

**Trading Operations:**
- `orders` - Order lifecycle management
- `trades` - Executed trades with brokerage details
- `positions` - Current open positions
- `position_history` - Closed positions with P&L

**Market Data:**
- `instruments` - Stocks, futures, options
- `market_data` - Real-time tick data (7-day TTL)
- `candles` - OHLC data (multiple timeframes)

**Strategy Management:**
- `strategies` - Algorithm definitions
- `strategy_state` - Execution state per account
- `signals` - Trading signals generated
- `strategy_performance` - Performance metrics

**Risk & Compliance:**
- `risk_limits` - Per-account/strategy limits
- `daily_risk_metrics` - Daily risk tracking
- `audit_log` - All critical operations
- `alerts` - System notifications

## 🔌 Connection Examples

### From Application (Python)

```python
import psycopg2

conn = psycopg2.connect(
    host='cockroachdb-public.trading.svc.cluster.local',
    port=26257,
    database='openalgo',
    user='openalgo',
    password='trading123',
    sslmode='disable'
)

# Place order
with conn.cursor() as cur:
    cur.execute("""
        INSERT INTO orders (account_id, instrument_id, order_type, 
                           transaction_type, product_type, quantity, price)
        VALUES (%s, %s, 'LIMIT', 'BUY', 'DELIVERY', %s, %s)
        RETURNING id
    """, (account_id, instrument_id, 100, 2550.50))
    order_id = cur.fetchone()[0]
conn.commit()
```

### From kubectl

```bash
# SQL shell
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 -d openalgo

# Run query
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 \
  -e "SELECT * FROM v_active_positions;"
```

### Admin UI

```bash
# Port forward
kubectl -n trading port-forward cockroachdb-0 8080:8080

# Open browser to http://localhost:8080
```

## 📈 Performance Tips

### Connection Pooling
Always use connection pooling in your application:
```python
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    'postgresql://openalgo:trading123@cockroachdb-public:26257/openalgo?sslmode=disable',
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=40
)
```

### Batch Operations
Use batch inserts for high-volume data:
```sql
INSERT INTO trades (symbol, side, quantity, price, timestamp)
VALUES 
    ('AAPL', 'BUY', 100, 150.50, NOW()),
    ('GOOGL', 'SELL', 50, 2800.00, NOW()),
    ('MSFT', 'BUY', 75, 300.25, NOW());
```

### Indexes
Key indexes are already created for common queries:
- `idx_orders_account_status` - Order queries by account
- `idx_trades_account_executed` - Trade history
- `idx_market_data_instrument_time` - Market data lookups
- `idx_positions_account` - Active positions

## 🔍 Monitoring

### Quick Health Checks

```bash
# Cluster status
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach node status --insecure

# Database size
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "SELECT table_name, total_bytes FROM crdb_internal.table_sizes WHERE database_name = 'openalgo';"

# Active queries
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "SELECT query, start FROM crdb_internal.cluster_queries ORDER BY start DESC LIMIT 10;"
```

### Metrics to Watch
- **Latency**: p50, p99 query latencies
- **Throughput**: QPS (queries per second)
- **Replication**: Under-replicated ranges
- **Storage**: Disk usage per node
- **Connection Pool**: Active connections

## 🛠️ Common Operations

### Scaling

```bash
# Scale to 6 nodes
kubectl -n trading scale statefulset cockroachdb --replicas=6

# Verify
kubectl -n trading get pods
```

### Backup

```bash
# Full database backup
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "BACKUP DATABASE openalgo TO 'nodelocal://1/backups/$(date +%Y%m%d)';"
```

### Restore

```bash
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "RESTORE DATABASE openalgo FROM 'nodelocal://1/backups/20240208';"
```

## 🔧 Troubleshooting

### Pod Not Starting
```bash
# Check events
kubectl -n trading describe pod cockroachdb-0

# Check logs
kubectl -n trading logs cockroachdb-0
```

### Connection Failed
```bash
# Test service
kubectl -n trading get svc cockroachdb-public

# Test connectivity from client
kubectl -n trading exec -it cockroachdb-client -- \
  nc -zv cockroachdb-public 26257
```

### Performance Issues
```bash
# Check for hot ranges
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach sql --insecure -e \
  "SELECT * FROM crdb_internal.ranges ORDER BY range_size DESC LIMIT 10;"
```

## 📚 Documentation

- **[Architecture Guide](cockroachdb-k8s-trading-guide.md)** - Complete architectural overview and best practices
- **[Deployment Guide](deployment-guide.md)** - Detailed deployment steps, testing, and operations

## 🔐 Security Notes

**⚠️ This deployment uses `--insecure` mode for simplicity.**

For production:
1. Generate TLS certificates
2. Create Kubernetes secrets
3. Update StatefulSet to use certificates
4. Enable RBAC and network policies
5. Use strong passwords (not `trading123`)

See deployment guide for security hardening steps.

## 💡 Key Features

### Fault Tolerance
- Cluster survives 1 node failure
- Automatic failover (no manual intervention)
- Data remains available during node maintenance

### Zero-Downtime Operations
- Rolling updates of CockroachDB version
- Scale up/down without downtime
- Online schema changes

### Data Consistency
- Serializable isolation (strongest ACID guarantee)
- No dirty reads, phantom reads, or lost updates
- Perfect for financial transactions

### Performance
- Multi-version concurrency control (MVCC)
- Distributed query optimization
- Secondary indexes for fast lookups

## 🎓 Learning Resources

- [CockroachDB Docs](https://www.cockroachlabs.com/docs/)
- [Kubernetes StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [CockroachDB University](https://university.cockroachlabs.com/)
- [Trading System Design Patterns](https://martinfowler.com/eaaDev/)

## 📝 License & Support

This is a reference implementation for educational purposes.

For production use:
- Review and test thoroughly in staging
- Consider CockroachDB Cloud for managed service
- Implement comprehensive monitoring and alerting
- Follow security best practices

## 🤝 Contributing

Improvements welcome! Consider:
- Production security configurations
- Multi-region deployment examples
- Prometheus/Grafana dashboards
- Helm charts
- CI/CD pipelines

## ⚡ Quick Commands Reference

```bash
# Deploy everything
kubectl apply -f .

# Check status
kubectl -n trading get all

# SQL shell
kubectl -n trading exec -it cockroachdb-client -- \
  ./cockroach sql --insecure --host=cockroachdb-public:26257 -d openalgo

# Admin UI
kubectl -n trading port-forward cockroachdb-0 8080:8080

# Cluster status
kubectl -n trading exec -it cockroachdb-0 -- \
  ./cockroach node status --insecure

# Cleanup
kubectl delete namespace trading
```

---

**Built for high-performance algorithmic trading. Deployed on Kubernetes. Powered by CockroachDB.**
