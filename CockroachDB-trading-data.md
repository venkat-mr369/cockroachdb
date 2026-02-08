Here's your comprehensive architecture document covering the full CockroachDB data flow for a trading database on your 4-node CentOS 9 cluster. It includes:

- **All 5 layers deep-dived** — SQL, Transaction, Distribution, Replication (Raft), and Storage (Pebble) — with trading-specific explanations
- **End-to-end trace** of a trade INSERT flowing through all layers across your specific nodes (192.168.235.231–234), including which nodes participate at each step
- **Latency breakdown** per layer
- **Complete trading schema** (orders, trades, positions, market_data, accounts) with composite PKs designed to avoid hotspots and co-locate related data
- **Replication & fault tolerance matrix** — what happens when 1 node, 2 nodes go down, or network partitions
- **Zone configurations** for different trading tables
- **CentOS 9 OS tuning**, cluster settings, and HAProxy load balancing config
- **Monitoring metrics** critical for trading workloads

cockroachdb_trading_architecture [cockroachdb_trading_architecture.docx]
