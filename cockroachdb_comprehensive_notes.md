### COCKROACHDB COMPREHENSIVE
#### Complete Chapter-wise In-depth Study Guide

---

## CHAPTER 1: CONFIGURATION & DEPLOYMENT

### 1.1 Architecture Fundamentals

**SHARED-NOTHING DISTRIBUTED SQL ARCHITECTURE**
- Each node operates independently without shared storage/memory
- Horizontal scalability through adding nodes
- No single point of failure in design
- Combines SQL interface with distributed KV store

KEY BENEFITS:
• Linear scaling with node addition
• Fault isolation between nodes  
• Geographic distribution capability
• Automatic data rebalancing

**NODES, STORES, RANGES, REPLICAS - HIERARCHY**

CLUSTER STRUCTURE:
```
Cluster
 └── Nodes (physical/virtual machines)
      └── Stores (one per disk typically)
           └── Ranges (512MB segments of data)
                └── Replicas (copies across nodes)
```

NODE DETAILS:
- Unique immutable Node ID assigned at bootstrap
- Runs both SQL and storage layers
- Participates in gossip network
- Can host multiple stores

STORE DETAILS:
- Logical storage unit with unique Store ID
- Typically one store per physical disk
- Independent Pebble storage engine instance
- Can be tagged with attributes (ssd, hdd, nvme)

RANGE DETAILS:
- Fundamental unit = 512MB (default, configurable)
- Contiguous key-value segment
- Automatically splits when size threshold reached
- Merges when too small (< 16MB default)
- Enables range scans due to sorted keys

REPLICA DETAILS:
- Default replication factor: 3 copies
- Distributed across different nodes/zones
- Participate in Raft consensus group
- One replica is designated leaseholder

**LEASEHOLDERS & LEADERSHIP**

LEASEHOLDER ROLE:
- Serves ALL reads for the range
- Coordinates writes
- Time-bound lease (default 9 seconds, auto-renewed)
- Usually colocated with Raft leader
- Can be manually placed for latency optimization

RAFT LEADER ROLE:
- Coordinates write consensus
- Elected through Raft protocol
- Term-based (increments on new election)
- Can differ from leaseholder

WHY TWO ROLES?
- Leaseholder: Enables consistent reads without consensus overhead
- Raft Leader: Ensures safe, replicated writes
- Independent optimization of read vs write paths

**SQL LAYER VS KV LAYER**

SQL LAYER (Upper):
- PostgreSQL-wire compatible
- Query parsing and optimization
- Transaction coordination
- Distributed execution planning
- Result aggregation and streaming

KV LAYER (Lower):
- Key-value storage (Pebble engine)
- Raft consensus implementation
- Data replication
- Range management (splits/merges)
- Automatic rebalancing

DATA FLOW:
1. SQL query arrives → SQL layer parses
2. Optimizer creates distributed plan
3. Plan translated to KV operations
4. KV operations sent to appropriate ranges
5. Raft ensures consistency for writes
6. Results gathered and returned via SQL layer

**RAFT CONSENSUS - MAJORITY QUORUM**

CORE CONCEPT:
- Distributed consensus algorithm
- Ensures all replicas agree on state
- Requires majority (quorum) for operations
- Based on replicated log

QUORUM REQUIREMENTS:
- 3 replicas → need 2 acknowledgments (can lose 1)
- 5 replicas → need 3 acknowledgments (can lose 2)  
- Formula: Quorum = floor(N/2) + 1

WRITE PROCESS:
1. Write arrives at leaseholder (Raft leader)
2. Leader appends to its Raft log
3. Leader sends to follower replicas
4. Followers append and acknowledge
5. Leader waits for majority ACKs
6. Entry marked committed
7. Applied to state machine
8. Client receives confirmation

HEARTBEATS:
- Leader sends every 1 second (default)
- Maintains leadership
- Carries commit index updates
- Timeout triggers new election (3s default)

**STRONG CONSISTENCY - SERIALIZABLE ISOLATION**

COCKROACHDB DEFAULT: Serializable isolation
- Strongest isolation level
- Transactions execute as if serial (one at a time)
- No anomalies: dirty reads, phantom reads, write skew

IMPLEMENTATION:
1. MVCC (Multi-Version Concurrency Control)
   - Multiple versions of data with timestamps
   - Readers see consistent snapshot
   - Writers create new versions

2. Write Intents
   - Provisional writes act as locks
   - Conflict detection mechanism
   - Resolved on commit/abort

3. Timestamp Ordering
   - Hybrid Logical Clocks (HLC)
   - Physical time + logical counter
   - Determines serialization order

TRANSACTION FLOW:
BEGIN → Assign timestamp → Execute with snapshot reads → Write intents → 
Check conflicts → COMMIT/RETRY

**REGION-AWARE TOPOLOGY**

LOCALITY HIERARCHY:
```
region → datacenter → zone → rack → node
```

CONFIGURATION EXAMPLE:
```bash
--locality=region=us-east,zone=us-east-1a,rack=r1
```

BENEFITS:
1. Fault Tolerance: Replicas across failure domains
2. Performance: Leaseholders near users  
3. Compliance: Data residency (GDPR)
4. Cost: Minimize cross-region traffic

MULTI-REGION PATTERNS:
- REGIONAL BY ROW: Each row pinned to region
- REGIONAL BY TABLE: Whole table in one region
- GLOBAL: Replicated everywhere for fast reads

---

### 1.2 Deployment Models

**SINGLE-NODE (DEV/TESTING)**

USE: Local development, testing, CI/CD

START COMMAND:
```bash
cockroach start-single-node --insecure   --listen-addr=localhost:26257   --http-addr=localhost:8080
```

LIMITATIONS:
❌ No fault tolerance (RF=1)
❌ No HA
❌ Not production-representative
❌ Can't test distributed features

**MULTI-NODE ON BARE METAL**

ADVANTAGES:
✓ Maximum performance (no virtualization overhead)
✓ Full hardware control
✓ Predictable resources

DISADVANTAGES:
✗ Higher initial cost
✗ Slower provisioning
✗ Less flexible

SETUP:
```bash
# Node 1
cockroach start --certs-dir=certs   --advertise-addr=node1:26257   --join=node1:26257,node2:26257,node3:26257

# Node 2, 3: Similar with different advertise-addr

# Initialize cluster (once)
cockroach init --certs-dir=certs --host=node1
```

**MULTI-NODE ON VIRTUAL MACHINES**

PLATFORMS: VMware, KVM, Hyper-V, cloud VMs

ADVANTAGES:
✓ Resource flexibility
✓ Easier migration
✓ Snapshot capabilities
✓ Better hardware utilization

DISADVANTAGES:
✗ Virtualization overhead (~5-10%)
✗ Resource contention possible
✗ Licensing costs (some platforms)

**KUBERNETES DEPLOYMENT**

MANUAL (StatefulSets):
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cockroachdb
spec:
  serviceName: cockroachdb
  replicas: 3
  template:
    spec:
      containers:
      - name: cockroachdb
        image: cockroachdb/cockroach:latest
        volumeMounts:
        - name: datadir
          mountPath: /cockroach/cockroach-data
  volumeClaimTemplates:
  - metadata:
      name: datadir
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 100Gi
```

OPERATOR-BASED:
- CockroachDB Kubernetes Operator
- Automated lifecycle management
- Rolling upgrades
- Self-healing
- Simplified operations

**CLOUD-MANAGED VS SELF-HOSTED**

CLOUD-MANAGED (CockroachDB Cloud):
✓ Zero operational overhead
✓ Automatic backups/upgrades
✓ Built-in monitoring
✓ Support included
✗ Less customization
✗ Higher per-resource cost

SELF-HOSTED:
✓ Full control
✓ Can optimize for workload
✓ Lower cost (if infra exists)
✗ Operational burden
✗ Manual upgrades/backups
✗ Need expertise

**MULTI-REGION DEPLOYMENTS**

TOPOLOGY DESIGN:
- 3+ regions for HA
- Odd number of regions for quorum
- Consider latency between regions (50-200ms typical)

CONFIGURATION:
```sql
CREATE DATABASE mydb PRIMARY REGION "us-east" 
  REGIONS "us-west", "eu-central";
  
ALTER TABLE users SET LOCALITY REGIONAL BY ROW;
```

**ACTIVE-ACTIVE GLOBAL CLUSTERS**

CHARACTERISTICS:
- All regions accept writes simultaneously
- No primary/secondary distinction
- Users routed to nearest region
- Transaction coordination across regions

BENEFITS:
✓ Low latency globally
✓ No failover delays
✓ Better resource utilization

CHALLENGES:
⚠ Cross-region coordination overhead
⚠ Network dependency
⚠ Higher operational complexity

---

### 1.3 Installation & Bootstrap

**BINARY INSTALLATION**

DOWNLOAD & INSTALL:
```bash
# Linux
wget https://binaries.cockroachdb.com/cockroach-latest.linux-amd64.tgz
tar -xzf cockroach-latest.linux-amd64.tgz
sudo cp cockroach-latest.linux-amd64/cockroach /usr/local/bin/

# Verify
cockroach version
```

PROS: Simple, direct system integration
CONS: Manual updates, platform-specific builds

**CONTAINER IMAGE**

DOCKER:
```bash
docker pull cockroachdb/cockroach:latest
docker run -d   --name=roach1   -p 26257:26257   -p 8080:8080   -v roachdata:/cockroach/cockroach-data   cockroachdb/cockroach:latest start-single-node --insecure
```

PROS: Consistent environments, easy versioning
CONS: Container runtime required, volume management

**SECURE VS INSECURE MODE**

INSECURE MODE (Dev only):
```bash
cockroach start --insecure --listen-addr=localhost:26257
```
- No TLS encryption
- No authentication
- Never for production

SECURE MODE (Production):
```bash
# 1. Create CA
cockroach cert create-ca --certs-dir=certs --ca-key=ca.key

# 2. Create node certificates
cockroach cert create-node node1.example.com   --certs-dir=certs --ca-key=ca.key

# 3. Create client certificate
cockroach cert create-client root   --certs-dir=certs --ca-key=ca.key

# 4. Start secure
cockroach start --certs-dir=certs   --advertise-addr=node1.example.com:26257
```

**CLUSTER BOOTSTRAP PROCESS**

STEP-BY-STEP:
```bash
# 1. Start first node (waits for init)
cockroach start --certs-dir=certs   --advertise-addr=node1:26257   --join=node1:26257,node2:26257,node3:26257

# 2. Start additional nodes
cockroach start --certs-dir=certs   --advertise-addr=node2:26257   --join=node1:26257,node2:26257,node3:26257

# 3. Initialize cluster (one time)
cockroach init --certs-dir=certs --host=node1:26257
```

WHAT HAPPENS ON INIT:
- Creates system ranges
- Establishes Raft groups
- Sets up metadata structures
- Assigns range replicas
- Creates default databases (system, defaultdb)

**JOIN FLAGS AND NODE DISCOVERY**

JOIN FORMAT:
```bash
--join=node1:26257,node2:26257,node3:26257
```

DISCOVERY PROCESS:
1. New node contacts any node from join list
2. Receives cluster topology via gossip
3. Learns about all nodes
4. Begins participating

BEST PRACTICES:
✓ List all nodes in join (for resilience)
✓ Use DNS names (not IPs)  
✓ Keep join list consistent
✓ Plan for expansion

**NODE IDs AND CLUSTER IDs**

NODE ID:
- Unique integer (1, 2, 3, ...)
- Assigned on first start
- Persists in data directory
- Immutable

CLUSTER ID:
- UUID generated during init
- Identifies the cluster
- Prevents wrong cluster joins
- Stored in all node data directories

VIEW IDs:
```sql
-- Node IDs
SELECT node_id FROM crdb_internal.gossip_nodes;

-- Cluster ID  
SHOW CLUSTER SETTING cluster.organization;
```

**GOSSIP NETWORK BASICS**

PURPOSE: Peer-to-peer metadata sharing

SHARED INFORMATION:
- Node liveness
- Store capacity  
- Range locations
- Network topology
- Configuration changes

PROTOCOL:
1. Each node maintains partial view
2. Periodically exchanges with random peers
3. Information propagates exponentially
4. Converges quickly (log N rounds)

MONITORING:
```sql
SELECT * FROM crdb_internal.gossip_network;
SELECT * FROM crdb_internal.gossip_liveness;
```

---

### 1.4 Node Configuration

**STORAGE ENGINE - PEBBLE**

WHAT IS PEBBLE?
- LSM-tree based key-value store
- CockroachDB-maintained fork of RocksDB
- Written in Go for better integration
- Default since v21.1

LSM-TREE STRUCTURE:
```
MemTable (RAM)
  ↓ flush when full
L0 (SSTables - disk)
  ↓ compaction
L1, L2, L3, L4, L5, L6 (progressively larger levels)
```

CHARACTERISTICS:
✓ Fast writes (append to log + memtable)
✓ Read amplification (check multiple levels)
✓ Background compaction
✓ Excellent for write-heavy workloads

**STORE CONFIGURATION & DISK LAYOUTS**

STORE FLAGS:
```bash
--store=path=/mnt/ssd1,size=500GB,attrs=ssd
--store=path=/mnt/hdd1,size=2TB,attrs=hdd
```

PARAMETERS:
- path: Data directory
- size: Max storage (prevents overflow)
- attrs: Custom tags for placement

MULTIPLE STORES:
- One per physical disk recommended
- Better disk utilization
- Finer failure isolation
- Each store independent

RECOMMENDED LAYOUT:
```
/mnt/data1/cockroach-data/    # Store 1
/mnt/data2/cockroach-data/    # Store 2 (if multiple disks)
/var/log/cockroach/           # Separate logging volume
```

**WAL BEHAVIOR**

WRITE-AHEAD LOG:
- All writes go to WAL first
- Ensures durability
- Sequential writes (fast)
- Truncated after flush to SSTable

LIFECYCLE:
1. Write arrives
2. Append to WAL
3. Write to memtable
4. fsync() on WAL
5. ACK to client
6. Eventually flush to SST
7. WAL entry discarded

PERFORMANCE TIPS:
- WAL on separate fast disk can help
- Monitor WAL size (indicates write pressure)
- Slow fsync = disk issues

**CACHE SIZES**

BLOCK CACHE:
- Caches decompressed SST blocks
- Shared across stores
- Default: 25% system memory

CONFIGURATION:
```bash
--cache=4GB  # Explicit size
```

SIZING GUIDELINES:
- Larger = better read performance
- Leave RAM for OS page cache
- Monitor cache hit ratio
- Typical: 25-50% of total RAM

**SQL MEMORY LIMITS**

PURPOSE: Query execution, sorts, joins, aggregations

CONFIGURATION:
```bash
--max-sql-memory=25%  # Percentage
--max-sql-memory=8GB  # Explicit size
```

PER-QUERY LIMIT:
```sql
SET CLUSTER SETTING sql.distsql.temp_storage.workmem = '64MB';
```

OVERFLOW HANDLING:
- Spill to disk when exceeded
- Use temp storage
- May reject very large queries

**BACKGROUND JOBS TUNING**

JOB TYPES:
- Compaction (LSM-tree maintenance)
- Range rebalancing
- Statistics collection
- Schema changes
- GC (garbage collection)

THROTTLING:
```sql
-- Rebalancing
SET CLUSTER SETTING kv.snapshot_rebalance.max_rate = '32MB';

-- Statistics
SET CLUSTER SETTING sql.stats.automatic_collection.enabled = true;
```

**CLOCK SYNCHRONIZATION (NTP IMPORTANCE)**

WHY CRITICAL?
- CockroachDB uses Hybrid Logical Clocks
- Physical time component affects causality
- Large skew causes unavailability

MAX TOLERATED SKEW: 500ms (default)

NTP SETUP:
```bash
# Ubuntu/Debian
sudo apt-get install ntp
sudo systemctl enable ntp
sudo systemctl start ntp

# Check status
ntpq -p
```

MONITORING:
```sql
SELECT * FROM crdb_internal.node_metrics 
WHERE name = 'clock-offset.meannanos';
```

ALERT: If offset > 500ms, cluster becomes unavailable

CLOUD TIME SYNC:
- AWS: EC2 Time Sync Service
- GCP: VM time sync
- Azure: Host time sync

---

### 1.5 Networking

**CLIENT VS INTER-NODE PORTS**

DEFAULT PORTS:
- 26257: SQL + inter-node communication
- 8080: HTTP Admin UI + metrics

CONFIGURATION:
```bash
--listen-addr=10.0.1.5:26257    # Internal network
--http-addr=10.0.1.5:8080       # Admin UI
--advertise-addr=10.0.1.5:26257 # Address others use
```

SECURITY:
- Restrict 26257 to cluster + clients only
- Limit 8080 to admin networks
- Use firewalls
- Never expose 8080 to internet

**LOAD BALANCER STRATEGIES**

WHY LOAD BALANCERS?
- Single endpoint for clients
- Health-based routing
- Automatic failover
- Connection distribution

TYPES:

Layer 4 (TCP):
- Simple round-robin
- Low overhead
- Good for most workloads

Layer 7 (Application):
- SQL-aware
- Session affinity  
- Higher overhead

HEALTH CHECK:
```
HTTP GET http://<node>:8080/health?ready=1
```

RESPONSES:
- 200 OK: Node ready
- 503: Not ready
- No response: Down

HAPROXY CONFIG:
```
listen cockroachdb
    bind :26257
    mode tcp
    balance roundrobin
    option httpchk GET /health?ready=1
    server node1 10.0.1.1:26257 check port 8080
    server node2 10.0.1.2:26257 check port 8080
    server node3 10.0.1.3:26257 check port 8080
```

**CONNECTION ROUTING**

FLOW:
```
Client → Load Balancer → Gateway Node → Leaseholder(s) → Response
```

DISTRIBUTED QUERIES:
1. Client connects to any node (gateway)
2. Gateway parses SQL
3. Creates distributed execution plan
4. Routes sub-queries to data locations
5. Aggregates results
6. Returns to client

FOLLOWER READS:
- Read from any replica (not just leaseholder)
- Slightly stale data (bounded by closed timestamp)
- Lower latency

ENABLE:
```sql
SELECT * FROM table AS OF SYSTEM TIME follower_read_timestamp();
```

**LATENCY IMPACT ON RAFT**

WRITE LATENCY FORMULA:
```
Total ≈ Network RTT/2 + Disk Write + Processing
```

EXAMPLES:
- Same DC (1ms RTT): 2-3ms total
- Same region (10ms RTT): 12-15ms total
- Cross-region (100ms RTT): 110-120ms total

RAFT HEARTBEATS:
- Interval: 1s (default)
- Detects failures
- Maintains leadership
- Affects failover time

OPTIMIZATION:
✓ Colocate replicas for low latency
✓ Fast networks (RDMA, InfiniBand)
✓ SSD/NVMe for WAL writes
✓ Tune Raft cautiously

---

## CHAPTER 2: CRDB TASKS & JOBS

### 2.1 Internal Job Framework

**JOB REGISTRY & LIFECYCLE**

JOB SYSTEM:
- Tracks long-running operations
- Persisted in system.jobs table
- Survives node restarts
- Distributed coordination

LIFECYCLE STATES:
```
Pending → Running → Succeeded
              ↓           ↓
          Paused      Failed → Reverting
              ↓
          Canceled
```

MONITORING:
```sql
SELECT job_id, job_type, status, fraction_completed 
FROM crdb_internal.jobs
WHERE status = 'running';
```

**JOB RETRY & FAILURE SEMANTICS**

AUTOMATIC RETRY:
- Transient errors retried
- Exponential backoff
- Max retry limits

ERROR TYPES:

Transient (retried):
- Network timeouts
- Temporary unavailability
- Lock conflicts

Permanent (not retried):
- Invalid schema
- Constraint violations
- User cancellation

RECOVERY:
```sql
-- Resume failed job
RESUME JOB 123456789;

-- Cancel job
CANCEL JOB 123456789;
```

---

### 2.2 Common Job Types

**BACKUP / RESTORE JOBS**

CREATE BACKUP:
```sql
-- Full backup
BACKUP DATABASE mydb TO 's3://bucket/backup';

-- Incremental
BACKUP DATABASE mydb TO 'latest' IN 's3://bucket/backup';
```

RESTORE:
```sql
RESTORE DATABASE mydb FROM 's3://bucket/backup';
```

MONITOR:
```sql
SHOW JOBS WHERE job_type IN ('BACKUP', 'RESTORE');
```

**SCHEMA CHANGES**

ONLINE SCHEMA CHANGES:
- Non-blocking
- Uses backfill process
- Versioned transitions

EXAMPLE:
```sql
ALTER TABLE users ADD COLUMN email VARCHAR(255);
```

PHASES:
1. Validation
2. Backfill (populate data)
3. Validation
4. Finalization

**INDEX CREATION & DROPS**

CREATE:
```sql
CREATE INDEX idx_email ON users(email);
```

PROCESS:
1. Setup metadata
2. Backfill (scan table, build index)
3. Validation
4. Activation

DROP:
```sql
DROP INDEX idx_email;
```

**STATISTICS REFRESH**

PURPOSE: Query optimizer statistics

AUTO-COLLECTION:
```sql
SET CLUSTER SETTING sql.stats.automatic_collection.enabled = true;
```

MANUAL:
```sql
CREATE STATISTICS stats_users FROM users;
```

TRIGGERS:
- 20% data change threshold
- New table creation
- Manual request

**GC JOBS**

GARBAGE COLLECTION:
- Removes old MVCC versions
- Reclaims disk space
- Background process

TTL SETTING:
```sql
ALTER TABLE users CONFIGURE ZONE USING gc.ttlseconds = 90000;
-- Default: 25 hours
```

**CHANGEFEEDS**

CDC (Change Data Capture):
```sql
CREATE CHANGEFEED FOR TABLE users 
INTO 'kafka://broker:9092?topic=users';
```

FEATURES:
- Stream changes to external systems
- At-least-once delivery
- Supports Kafka, webhooks, cloud storage

---

### 2.3 Task Scheduling

**BACKGROUND TASK THROTTLING**

MECHANISMS:
- Rate limiting
- Resource quotas
- Priority queues

CONFIGURATION:
```sql
SET CLUSTER SETTING kv.snapshot_rebalance.max_rate = '32MB';
SET CLUSTER SETTING kv.bulk_io_write.max_rate = '32MB';
```

**JOB PRIORITY HANDLING**

LEVELS:
1. High: Critical system operations
2. Normal: User jobs
3. Low: Background maintenance

EXAMPLES:
- Schema changes: Normal
- Backups: Normal
- Statistics: Low
- GC: Low

**RESOURCE CONTENTION CONTROL**

CONTENTION TYPES:
- CPU: Backfill vs queries
- Memory: Jobs vs SQL execution
- Disk: WAL vs compaction
- Network: Replication vs clients

MITIGATION:
- Rate limiting
- Resource pools
- Admission control
- Scheduling windows

---

### 2.4 Job Monitoring

**VIEWING JOB STATUS**

BASIC QUERY:
```sql
SELECT job_id, job_type, status, created, fraction_completed
FROM crdb_internal.jobs
ORDER BY created DESC
LIMIT 20;
```

BY TYPE:
```sql
SELECT * FROM crdb_internal.jobs 
WHERE job_type = 'BACKUP' AND status = 'running';
```

PROGRESS:
```sql
SELECT job_id, 
       fraction_completed * 100 AS percent,
       running_status
FROM crdb_internal.jobs
WHERE status = 'running';
```

**DIAGNOSING STUCK JOBS**

SIGNS:
- No progress change
- Long running time
- Repeated errors

DIAGNOSIS:
```sql
-- 1. Check job details
SELECT * FROM crdb_internal.jobs WHERE job_id = 123456789;

-- 2. Check node health
SELECT node_id, is_live FROM crdb_internal.gossip_liveness;

-- 3. Check resources
SELECT * FROM crdb_internal.node_metrics WHERE name LIKE 'sys.%';

-- 4. Check locks
SELECT * FROM crdb_internal.cluster_locks WHERE contended = true;
```

**CANCELLING AND RESUMING**

CANCEL:
```sql
CANCEL JOB 123456789;
```

PAUSE:
```sql
PAUSE JOB 123456789;
```

RESUME:
```sql
RESUME JOB 123456789;
```

---

[DOCUMENT CONTINUES WITH CHAPTERS 3-7...]



## CHAPTER 3: SECURITY

### 3.1 Authentication & Identity

**CERTIFICATE-BASED AUTH**

PKI HIERARCHY:
```
CA Certificate (Root Trust)
├── Node Certificates (inter-node)
└── Client Certificates (users)
```

CREATE CA:
```bash
cockroach cert create-ca   --certs-dir=certs   --ca-key=ca.key   --lifetime=87600h
```

CREATE NODE CERT:
```bash
cockroach cert create-node   node1.example.com localhost 127.0.0.1   --certs-dir=certs   --ca-key=ca.key
```

CREATE CLIENT CERT:
```bash
cockroach cert create-client root   --certs-dir=certs   --ca-key=ca.key
```

**USER/PASSWORD AUTH**

CREATE USER:
```sql
CREATE USER app_user WITH PASSWORD 'secure_password';
```

PASSWORD SETTINGS:
- SCRAM-SHA-256 hashing (default)
- Complexity requirements
- Expiration policies

CONNECTION:
```bash
cockroach sql --user=app_user --host=node1
# Prompts for password
```

**CERTIFICATE ROTATION**

NODE CERT ROTATION:
1. Generate new certificates
2. Rolling update per node:
   - Stop node
   - Replace certs
   - Start node
3. Verify cluster health

CLIENT CERT ROTATION:
- Generate new cert
- Distribute to application  
- Old cert valid until replaced
- No downtime

---

### 3.2 Authorization & RBAC

**USERS, ROLES, AND GRANTS**

CREATE ROLE:
```sql
CREATE ROLE analysts;
CREATE ROLE developers;
```

GRANT ROLE:
```sql
GRANT analysts TO john;
GRANT developers TO jane;
```

ROLE HIERARCHY:
```sql
CREATE ROLE senior_analysts;
GRANT analysts TO senior_analysts;
GRANT senior_analysts TO mary;
-- mary inherits analysts permissions
```

**PRIVILEGE LEVELS**

CLUSTER-LEVEL:
- ADMIN: Full cluster access
- MODIFYCLUSTERSETTING: Change settings
- VIEWACTIVITY: View queries/sessions
- VIEWCLUSTERSETTING: Read settings

DATABASE-LEVEL:
```sql
GRANT CREATE, CONNECT ON DATABASE mydb TO developers;
```

Privileges: CREATE, CONNECT, DROP, ALL

SCHEMA-LEVEL:
```sql
GRANT USAGE, CREATE ON SCHEMA public TO developers;
```

Privileges: USAGE, CREATE, DROP, ALL

TABLE-LEVEL:
```sql
GRANT SELECT, INSERT, UPDATE ON TABLE users TO analysts;
```

Privileges: SELECT, INSERT, UPDATE, DELETE, DROP, CREATE, ALL

COLUMN-LEVEL:
```sql
GRANT SELECT (name, email) ON TABLE users TO support;
```

**ADMIN VS NON-ADMIN SEPARATION**

ADMIN CAPABILITIES:
✓ Create/drop databases
✓ Modify cluster settings
✓ View all data
✓ Manage users
✓ Execute privileged operations

CREATE ADMIN:
```sql
GRANT ADMIN TO alice;
```

PRINCIPLE OF LEAST PRIVILEGE:
```sql
-- BAD
GRANT ADMIN TO app_user;  # Overprivileged

-- GOOD
CREATE ROLE app_role;
GRANT SELECT, INSERT ON TABLE orders TO app_role;
GRANT app_role TO app_user;
```

---

### 3.3 Encryption

**TLS IN TRANSIT**

WHAT'S ENCRYPTED:
- Client-to-node (SQL)
- Node-to-node (Raft, gossip)
- Admin UI (HTTP)

SECURE MODE:
```bash
cockroach start --certs-dir=certs   --advertise-addr=node1.example.com
```

SSL MODES:
- disable: No encryption (insecure only)
- require: Encryption, no verification
- verify-ca: Verify server cert
- verify-full: Verify cert + hostname (recommended)

**ENCRYPTION AT REST**

APPROACH: Filesystem-level encryption
- dm-crypt/LUKS (Linux)
- Cloud provider encryption (EBS, GCP Disks)

LINUX dm-crypt:
```bash
cryptsetup luksFormat /dev/sdb
cryptsetup luksOpen /dev/sdb encrypted_disk
mount /dev/mapper/encrypted_disk /mnt/data
```

CLOUD OPTIONS:
- AWS: EBS encryption + KMS
- GCP: Disk encryption + Cloud KMS
- Azure: Disk encryption + Key Vault

BACKUP ENCRYPTION:
```sql
BACKUP DATABASE mydb TO 's3://bucket/backup'
WITH encryption_passphrase = 'strong_passphrase';
```

**KEY MANAGEMENT**

HIERARCHY:
```
Master Key (HSM/KMS)
  └── Data Encryption Keys
       └── Encrypted Data
```

BEST PRACTICES:
✓ Use HSM for master keys
✓ Automated rotation
✓ Separate key storage from data
✓ Audit key access
✓ Document recovery procedures

**PERFORMANCE IMPACT**

TLS OVERHEAD:
- CPU: 3-5% increase
- Latency: <1ms added
- Mitigated by AES-NI hardware acceleration

ENCRYPTION AT REST:
- CPU: 5-10% increase
- I/O: Negligible on modern SSDs
- Throughput: <10% reduction

OPTIMIZATION:
✓ CPUs with AES-NI
✓ Modern Intel/AMD processors
✓ Hardware acceleration enabled

---

### 3.4 Network Security

**FIREWALL RULES**

PORT REQUIREMENTS:
- 26257: Cluster nodes + clients
- 8080: Admin network only

IPTABLES EXAMPLE:
```bash
# Allow cluster communication
iptables -A INPUT -p tcp --dport 26257 -s 10.0.1.0/24 -j ACCEPT

# Allow client connections
iptables -A INPUT -p tcp --dport 26257 -s 10.0.2.0/24 -j ACCEPT

# Allow admin UI from admin network
iptables -A INPUT -p tcp --dport 8080 -s 192.168.1.0/24 -j ACCEPT

# Drop all else
iptables -A INPUT -p tcp --dport 26257 -j DROP
iptables -A INPUT -p tcp --dport 8080 -j DROP
```

CLOUD SECURITY GROUPS:
```yaml
# Inter-node (AWS)
- Type: Custom TCP
  Port: 26257
  Source: sg-cockroach-nodes

# Clients
- Type: Custom TCP
  Port: 26257
  Source: sg-app-servers

# Admin
- Type: Custom TCP
  Port: 8080
  Source: sg-admin-bastion
```

**mTLS TRUST MODEL**

MUTUAL TLS:
- Both client and server authenticate
- Both present certificates
- Both verify against CA

AUTHENTICATION FLOW:
```
1. Exchange certificates
2. Verify signatures against CA
3. Check expiration
4. Verify hostname (nodes)
5. Establish encrypted channel
```

BENEFITS:
✓ Strong authentication
✓ No password transmission
✓ Automatic encryption
✓ MITM attack prevention

**SECURE CLIENT CONNECTIVITY**

CONNECTION LEVELS:

Level 1 - Insecure (dev only):
```bash
--insecure
```

Level 2 - TLS + Password:
```bash
postgres://user:pass@host:26257?sslmode=require
```

Level 3 - mTLS (recommended):
```bash
postgres://host:26257?sslmode=verify-full&sslcert=client.crt&sslkey=client.key
```

APPLICATION CONFIG:

Python (psycopg2):
```python
import psycopg2
conn = psycopg2.connect(
    host="node1",
    port=26257,
    user="app_user",
    sslmode="verify-full",
    sslrootcert="/path/ca.crt",
    sslcert="/path/client.crt",
    sslkey="/path/client.key"
)
```

---

### 3.5 Auditing & Compliance

**SQL AUDIT LOGGING**

ENABLE AUDITING:
```sql
-- Full auditing
ALTER TABLE sensitive_data EXPERIMENTAL_AUDIT SET READ WRITE;

-- Read-only
ALTER TABLE users EXPERIMENTAL_AUDIT SET READ;

-- Write-only
ALTER TABLE transactions EXPERIMENTAL_AUDIT SET WRITE;
```

VIEW LOGS:
```sql
SELECT timestamp, user_name, table_name, operation, statement
FROM crdb_internal.audit_log
WHERE table_name = 'sensitive_data'
ORDER BY timestamp DESC;
```

**ACCESS TRACKING**

WHO ACCESSED WHAT:
```sql
SELECT user_name, table_name, COUNT(*) as access_count
FROM crdb_internal.audit_log
WHERE timestamp > NOW() - INTERVAL '7 days'
GROUP BY user_name, table_name
ORDER BY access_count DESC;
```

FAILED ATTEMPTS:
```sql
SELECT timestamp, user_name, client_address, error_message
FROM crdb_internal.authentication_log
WHERE success = false
ORDER BY timestamp DESC;
```

**COMPLIANCE FRAMEWORKS**

HIPAA (Healthcare):
- Audit PHI access
- Encryption at rest + transit
- Access controls
- Regular access reviews

PCI-DSS (Payment):
- Protect cardholder data
- Track all access
- Restrict on need-to-know
- Regular testing

GDPR (Privacy):
- Right to be forgotten
- Data portability
- Access logging
- Data minimization

SOC 2:
- Access controls
- Change management
- Monitoring/logging
- Incident response

IMPLEMENTATION:
```sql
-- HIPAA example
ALTER TABLE patient_records EXPERIMENTAL_AUDIT SET READ WRITE;
CREATE ROLE healthcare_provider;
GRANT SELECT ON TABLE patient_records TO healthcare_provider;

-- Regular access review
SELECT user_name, COUNT(*) as phi_access
FROM crdb_internal.audit_log
WHERE table_name IN ('patient_records', 'medical_history')
GROUP BY user_name;
```

---

## CHAPTER 4: BACKUP & RESTORE

### 4.1 Backup Architecture

**FULL VS INCREMENTAL BACKUPS**

FULL BACKUP:
- Complete snapshot
- Self-contained
- Baseline for incrementals

```sql
BACKUP DATABASE mydb TO 's3://bucket/full-2026-02-08';
```

INCREMENTAL BACKUP:
- Only changes since last backup
- Faster, smaller
- Requires full backup base

```sql
BACKUP DATABASE mydb TO 'latest' IN 's3://bucket/full';
```

BACKUP CHAIN:
```
Sunday: Full (100GB)
Monday: Incremental (+10GB changes)
Tuesday: Incremental (+12GB changes)
Total: 122GB vs 300GB (3 full backups)
```

**DISTRIBUTED SNAPSHOT MECHANISM**

PROCESS:
1. Choose consistent timestamp
2. All nodes backup their ranges in parallel
3. Each range backed up by leaseholder
4. Upload to external storage concurrently
5. Record metadata

CONSISTENCY:
- MVCC snapshot at single timestamp
- No partial transactions
- Cross-table consistency guaranteed

**BACKUP JOB INTERNALS**

PHASES:
1. Planning: Determine ranges, allocate to nodes
2. Execution: Parallel backup, checkpointing
3. Finalization: Write manifest, record completion

MONITORING:
```sql
SELECT job_id, fraction_completed * 100 AS percent
FROM crdb_internal.jobs
WHERE job_type = 'BACKUP' AND status = 'running';
```

---

### 4.2 Backup Targets

**LOCAL FILESYSTEM**

SYNTAX:
```sql
BACKUP DATABASE mydb TO 'nodelocal://1/backups';
```

USE CASES:
- Testing/development
- Temporary backups
- Fast local recovery

LIMITATIONS:
❌ Single node (not distributed)
❌ No automatic replication
❌ Node failure = backup loss
❌ Not for production

**OBJECT STORAGE**

AWS S3:
```sql
BACKUP DATABASE mydb 
TO 's3://bucket/backup?AWS_ACCESS_KEY_ID=xxx&AWS_SECRET_ACCESS_KEY=yyy&AWS_REGION=us-east-1';
```

GOOGLE CLOUD STORAGE:
```sql
BACKUP DATABASE mydb 
TO 'gs://bucket/backup?AUTH=specified&CREDENTIALS=base64-key';
```

AZURE BLOB:
```sql
BACKUP DATABASE mydb 
TO 'azure://container/backup?AZURE_ACCOUNT_NAME=xxx&AZURE_ACCOUNT_KEY=yyy';
```

BEST PRACTICES:
✓ Use IAM roles (not embedded credentials)
✓ Enable versioning
✓ Lifecycle policies for cost
✓ Cross-region replication

**ENCRYPTED BACKUPS**

PASSPHRASE:
```sql
BACKUP DATABASE mydb TO 's3://bucket/backup'
WITH encryption_passphrase = 'strong-passphrase';
```

RESTORE:
```sql
RESTORE DATABASE mydb FROM 's3://bucket/backup'
WITH encryption_passphrase = 'strong-passphrase';
```

SECURITY:
- AES-256 encryption
- Store passphrase in secrets manager
- Different passphrase per backup (optional)
- Test encrypted restore regularly

---

### 4.3 Restore Scenarios

**FULL CLUSTER RESTORE**

BACKUP:
```sql
BACKUP TO 's3://bucket/cluster-backup';
```

RESTORE PROCESS:
1. Provision new cluster
2. Initialize cluster
3. Restore:
   ```sql
   RESTORE FROM 's3://bucket/cluster-backup';
   ```
4. Verify data

RESTORES:
- All databases
- All users/roles
- Cluster settings
- Zone configurations

**DATABASE-LEVEL RESTORE**

BACKUP:
```sql
BACKUP DATABASE mydb TO 's3://bucket/mydb-backup';
```

RESTORE WITH NEW NAME:
```sql
RESTORE DATABASE mydb FROM 's3://bucket/mydb-backup'
WITH new_db_name = 'mydb_restored';
```

PARTIAL RESTORE:
```sql
RESTORE TABLE mydb.users, mydb.orders 
FROM 's3://bucket/mydb-backup';
```

**TABLE-LEVEL RESTORE**

BACKUP:
```sql
BACKUP TABLE mydb.users TO 's3://bucket/users-backup';
```

RESTORE:
```sql
RESTORE TABLE mydb.users FROM 's3://bucket/users-backup';
```

USE CASES:
- Accidental DELETE
- Table corruption
- Clone to dev environment
- Bad migration recovery

**POINT-IN-TIME RECOVERY (PITR)**

SETUP BACKUP CHAIN:
```sql
-- Sunday: Full
BACKUP DATABASE mydb TO 's3://bucket/backups/mydb';

-- Monday-Saturday: Incrementals
BACKUP DATABASE mydb TO 'latest' IN 's3://bucket/backups/mydb';
```

RESTORE TO SPECIFIC TIME:
```sql
RESTORE DATABASE mydb 
FROM '2026-02-08 13:59:00' IN 's3://bucket/backups/mydb';
```

USE CASES:
- Recover from bad deployment
- Audit historical data
- Compliance requirements
- Find pre-corruption state

---

### 4.4 Performance & Reliability

**BACKUP IMPACT ON WORKLOAD**

RESOURCE USAGE:
- CPU: 5-15% increase (compression/encryption)
- Disk I/O: 10-20% increase (reading data)
- Network: Upload bandwidth to cloud
- Memory: Buffering

IMPACT:
- Minimal on foreground queries
- Background task throttling
- Lower priority than user queries

MEASURING:
```sql
-- Monitor during backup
SELECT * FROM crdb_internal.node_metrics 
WHERE name LIKE 'sys.cpu%';
```

**THROTTLING STRATEGIES**

RATE LIMITING:
```sql
SET CLUSTER SETTING kv.bulk_io_write.max_rate = '32MB';
```

SCHEDULING:
- Run during low-traffic periods
- Off-peak hours
- Maintenance windows

INCREMENTAL FREQUENCY:
- Balance RPO vs overhead
- Daily incrementals common
- Hourly for critical systems

**BACKUP VERIFICATION**

TEST RESTORES:
- Regular restore tests
- Verify data integrity
- Document procedures
- Measure restore times

VALIDATION:
```sql
-- Show backup contents
SHOW BACKUP 's3://bucket/backup';

-- Verify checksums
SELECT * FROM [SHOW BACKUP 's3://bucket/backup'] WHERE validation_failed = true;
```

**DISASTER RECOVERY DESIGN**

RPO/RTO PLANNING:
- RPO (Recovery Point Objective): Max data loss tolerable
- RTO (Recovery Time Objective): Max downtime tolerable

STRATEGY:
```
Daily Full + Hourly Incrementals
RPO: 1 hour (last incremental)
RTO: 2-4 hours (restore time)
```

RETENTION POLICIES:
```
Daily backups: 30 days
Weekly backups: 12 weeks  
Monthly backups: 1 year
```

MULTI-REGION DR:
- Backup to different region
- Cross-region replication
- Test failover procedures
- Document recovery runbooks

---

## CHAPTER 5: MONITORING & ALERTING

### 5.1 Built-in Admin UI

ACCESS:
```
http://node1:8080
```

KEY FEATURES:
1. Cluster Overview
   - Node health
   - QPS (queries per second)
   - Storage usage
   - CPU/memory metrics

2. SQL Activity
   - Active queries
   - Transaction statistics
   - Slow query log

3. Range Status
   - Range distribution
   - Hot ranges
   - Under-replicated ranges

4. Network Latency
   - Inter-node latency
   - Geo-distribution view

**NODE HEALTH INDICATORS**

METRICS:
- is_live: Node responding to heartbeats
- is_available: Node accepting connections
- updated_at: Last liveness update

VIEW:
```sql
SELECT node_id, is_live, is_available 
FROM crdb_internal.gossip_liveness;
```

ALERTS:
- Node down
- High CPU/memory
- Disk pressure
- Clock offset

**HOT RANGES**

IDENTIFICATION:
- High QPS on specific ranges
- Uneven load distribution
- Performance bottleneck

VIEW IN UI:
Navigate to: Metrics → Hot Ranges

MITIGATION:
- Range splits
- Schema design changes
- Application query optimization

---

### 5.2 Metrics & Telemetry

**KEY METRICS**

SYSTEM METRICS:
- sys.cpu.combined.percent-normalized
- sys.mem.available
- sys.disk.iopsinprogress
- sys.disk.read.bytes
- sys.disk.write.bytes

RAFT METRICS:
- raft.process.commandcommit.latency
- raft.rcvd.heartbeat
- raft.process.tickingnanos

REPLICATION:
- ranges.overreplicated
- ranges.underreplicated
- replicas.quiescent

SQL METRICS:
- sql.select.count
- sql.insert.count
- sql.update.count
- sql.txn.commit.count
- sql.txn.rollback.count

QUERY:
```sql
SELECT * FROM crdb_internal.node_metrics 
WHERE name LIKE 'sql.%';
```

**NODE VS CLUSTER-WIDE METRICS**

NODE-LEVEL:
- Specific to single node
- System resources
- Local performance

CLUSTER-LEVEL:
- Aggregated across nodes
- Overall health
- Distributed operations

---

### 5.3 External Monitoring

**PROMETHEUS INTEGRATION**

ENDPOINT:
```
http://node1:8080/_status/vars
```

PROMETHEUS CONFIG:
```yaml
scrape_configs:
  - job_name: 'cockroachdb'
    static_configs:
      - targets:
        - 'node1:8080'
        - 'node2:8080'
        - 'node3:8080'
```

**GRAFANA DASHBOARDS**

SETUP:
1. Add Prometheus data source
2. Import CockroachDB dashboard
3. Customize for your needs

DASHBOARD PANELS:
- Node status
- QPS over time
- Query latency P99/P50
- Storage usage
- Replication health

**ALERTMANAGER SETUP**

RULES EXAMPLE:
```yaml
groups:
  - name: cockroachdb
    rules:
      - alert: NodeDown
        expr: up{job="cockroachdb"} == 0
        for: 5m
        annotations:
          summary: "CockroachDB node is down"
      
      - alert: UnderReplicated
        expr: ranges_underreplicated > 0
        for: 15m
        annotations:
          summary: "Ranges are under-replicated"
```

**LOG AGGREGATION**

ELK STACK:
- Elasticsearch: Store logs
- Logstash: Process logs
- Kibana: Visualize

LOG FORMAT:
- JSON structured logs
- Severity levels
- Timestamps
- Context fields

FORWARDING:
```bash
# Use filebeat or similar
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/cockroach/*.log
```

---

### 5.4 Alert Design

**CRITICAL ALERTS**

NODE DOWN:
```yaml
alert: NodeDown
expr: up == 0
for: 5m
severity: critical
```

UNDER-REPLICATED:
```yaml
alert: UnderReplicated
expr: ranges_underreplicated > 0  
for: 10m
severity: critical
```

DISK PRESSURE:
```yaml
alert: DiskPressure
expr: capacity_available < 0.1 * capacity
for: 5m
severity: warning
```

**WARNING ALERTS**

HIGH LATENCY:
```yaml
alert: HighLatency
expr: sql_exec_latency_p99 > 1000
for: 10m
severity: warning
```

CLOCK OFFSET:
```yaml
alert: ClockOffset
expr: clock_offset_meannanos > 250000000
for: 5m
severity: warning
```

**ALERT BEST PRACTICES**

GUIDELINES:
✓ Set appropriate thresholds
✓ Use 'for' clause to avoid flapping
✓ Include actionable context
✓ Test alert rules
✓ Document response procedures
✓ Review and tune regularly

NOTIFICATION CHANNELS:
- PagerDuty (critical)
- Slack (warnings)
- Email (informational)
- Webhook (custom integrations)

---

## CHAPTER 6: DIAGNOSTICS & DEBUGGING

### 6.1 Query-Level Diagnostics

**SQL EXECUTION PLANS**

VIEW PLAN:
```sql
EXPLAIN SELECT * FROM users WHERE email = 'alice@example.com';
```

ANALYZE WITH STATISTICS:
```sql
EXPLAIN ANALYZE SELECT * FROM users WHERE email = 'alice@example.com';
```

OUTPUT INTERPRETATION:
- Scan type (sequential vs index)
- Estimated rows
- Actual rows
- Execution time
- Node distribution

**DISTRIBUTED QUERY EXECUTION**

PHASES:
1. Gateway node parses query
2. Optimizer creates distributed plan
3. Sub-plans sent to relevant nodes
4. Parallel execution
5. Results aggregated
6. Return to client

VIEWING:
```sql
EXPLAIN (DISTSQL) SELECT * FROM large_table WHERE region = 'us-east';
```

**INDEX SELECTION ISSUES**

MISSING INDEX:
```sql
-- Sequential scan (slow)
EXPLAIN SELECT * FROM users WHERE email = 'alice@example.com';
-- Shows: Scan: full

-- Create index
CREATE INDEX idx_email ON users(email);

-- Now uses index
EXPLAIN SELECT * FROM users WHERE email = 'alice@example.com';
-- Shows: Scan: index
```

WRONG INDEX:
- Multiple indexes on table
- Optimizer chooses suboptimal
- Update statistics
- Use index hints

**TRANSACTION RETRIES ANALYSIS**

CAUSES:
- Write conflicts
- Clock uncertainty
- Serializable isolation

MONITORING:
```sql
SELECT * FROM crdb_internal.node_txn_stats
WHERE txn_retries > 0
ORDER BY txn_retries DESC;
```

MITIGATION:
- Reduce transaction duration
- Avoid hot spots
- Batch operations
- Use SELECT FOR UPDATE

---

### 6.2 Cluster-Level Troubleshooting

**REPLICA IMBALANCE**

DETECTION:
```sql
SELECT store_id, COUNT(*) as replica_count
FROM crdb_internal.ranges
GROUP BY store_id
ORDER BY replica_count DESC;
```

CAUSES:
- New node added
- Node decommissioned
- Uneven range splits

RESOLUTION:
- Wait for automatic rebalancing
- Manual rebalancing if needed
- Check zone configurations

**LEASEHOLDER HOTSPOTS**

IDENTIFICATION:
- High QPS on single range
- One node CPU maxed
- Uneven query distribution

VIEW:
```sql
SELECT range_id, lease_holder, qps
FROM crdb_internal.ranges
ORDER BY qps DESC
LIMIT 10;
```

MITIGATION:
```sql
-- Split hot range
ALTER TABLE users SPLIT AT VALUES (1000), (2000), (3000);

-- Adjust leaseholder preferences
ALTER TABLE users CONFIGURE ZONE USING 
  lease_preferences = '[[+region=us-east]]';
```

**SLOW RAFT GROUPS**

SYMPTOMS:
- High Raft latency
- Slow writes
- Increased transaction retries

DIAGNOSIS:
```sql
SELECT * FROM crdb_internal.node_metrics 
WHERE name LIKE 'raft.process%'
ORDER BY value DESC;
```

CAUSES:
- Network latency
- Disk I/O issues
- CPU saturation
- Large Raft logs

**NETWORK PARTITION SYMPTOMS**

INDICATORS:
- Nodes marked not live
- Increased gossip failures
- Client connection timeouts
- Range unavailability

DETECTION:
```sql
SELECT node_id, is_live, updated_at
FROM crdb_internal.gossip_liveness
WHERE is_live = false;
```

RESOLUTION:
- Check network connectivity
- Verify firewall rules
- Review security groups
- Check switch/router configs

---

### 6.3 Logs & Traces

**LOG STRUCTURE & SEVERITY**

LEVELS:
- FATAL: Process terminates
- ERROR: Serious issues
- WARNING: Potential problems
- INFO: General information
- DEBUG: Detailed debugging

LOCATION:
```
/var/log/cockroach/cockroach.log
```

FORMAT:
```
[timestamp] [severity] [file:line] message
```

**EVENT LOGS**

SPECIAL LOGS:
- Cluster events
- Range events
- Node events
- SQL audit logs

VIEW:
```sql
SELECT * FROM system.eventlog
ORDER BY timestamp DESC
LIMIT 100;
```

**DISTRIBUTED TRACING**

ENABLE:
```sql
SET tracing = on;
SELECT * FROM users WHERE id = 123;
SHOW TRACE FOR SESSION;
SET tracing = off;
```

OUTPUT:
- Operation timeline
- Node involvement
- KV operations
- Timing breakdown

INTEGRATION:
- Jaeger
- Zipkin
- OpenTelemetry

**CORRELATING SQL ISSUES WITH KV LAYER**

PROCESS:
1. Identify slow query in SQL logs
2. Extract query ID
3. Find corresponding KV operations
4. Check Raft latency
5. Identify bottleneck

EXAMPLE:
```sql
-- Find slow queries
SELECT * FROM crdb_internal.node_statement_statistics
WHERE mean_latency > 1000  -- milliseconds
ORDER BY mean_latency DESC;

-- Get execution details
SHOW TRACE FOR SELECT * FROM slow_table WHERE ...;
```

---

### 6.4 Debugging Failures

**NODE CRASH ANALYSIS**

STEPS:
1. Check logs for panic/fatal errors
2. Review system metrics before crash
3. Check disk space/memory
4. Verify clock synchronization
5. Review recent changes

LOG INVESTIGATION:
```bash
grep FATAL /var/log/cockroach/cockroach.log
grep panic /var/log/cockroach/cockroach.log
```

**DISK CORRUPTION SCENARIOS**

SYMPTOMS:
- Read/write errors
- Node failing to start
- Checksum failures

RECOVERY:
1. Stop affected node
2. Run filesystem check
3. Restore from backup if needed
4. Decommission and replace node

PREVENTION:
- Use reliable storage
- Enable ECC memory
- Regular backups
- Monitor SMART stats

**CLOCK SKEW ISSUES**

DETECTION:
```sql
SELECT * FROM crdb_internal.node_metrics 
WHERE name = 'clock-offset.meannanos'
AND value > 500000000;  -- 500ms
```

SYMPTOMS:
- Cluster unavailability
- Transaction errors
- Node marked as live but unreachable

RESOLUTION:
1. Fix NTP configuration
2. Restart affected nodes
3. Verify clock synchronization
4. Monitor clock offsets

**QUORUM LOSS HANDLING**

SCENARIO: Majority of replicas unavailable

SYMPTOMS:
- Range unavailable errors
- Write failures
- Read failures

RECOVERY:
1. Restore missing nodes
2. If nodes lost permanently:
   ```bash
   # Manual recovery (last resort)
   cockroach debug recover      --certs-dir=certs      --host=available-node:26257
   ```
3. May result in data loss
4. Restore from backup

PREVENTION:
- Monitor node health
- Automate node recovery
- Sufficient replication factor
- Geographic distribution

---

## CHAPTER 7: CLUSTER MAINTENANCE

### 7.1 Scaling Operations

**ADDING NODES**

PROCESS:
```bash
# Start new node
cockroach start   --certs-dir=certs   --advertise-addr=new-node:26257   --join=node1:26257,node2:26257,node3:26257
```

AUTOMATIC ACTIONS:
1. Node joins gossip network
2. Receives cluster topology
3. Begins accepting range replicas
4. Rebalancing occurs automatically

MONITORING:
```sql
-- Watch rebalancing progress
SELECT * FROM crdb_internal.ranges
WHERE replicas LIKE '%new-node%';
```

**DECOMMISSIONING NODES**

SAFE REMOVAL:
```bash
cockroach node decommission <node-id>   --certs-dir=certs   --host=node1:26257
```

PROCESS:
1. Mark node as decommissioning
2. Transfer replicas to other nodes
3. Drain client connections
4. Mark as decommissioned
5. Safe to shut down

MONITORING:
```bash
cockroach node status   --certs-dir=certs   --host=node1:26257
```

**REBALANCING REPLICAS**

AUTOMATIC REBALANCING:
- Triggered by imbalances
- Based on QPS, range count, disk usage
- Gradual to avoid disruption

MANUAL TRIGGER:
```sql
-- Force range split
ALTER TABLE users SPLIT AT VALUES (1000);

-- Configure rebalancing
SET CLUSTER SETTING kv.allocator.load_based_rebalancing = 'leases and replicas';
```

**STORAGE EXPANSION**

SCENARIOS:
1. Add disk to existing node
2. Replace with larger disk
3. Add new nodes

ADDING STORE:
```bash
# Stop node
systemctl stop cockroach

# Update config to add store
--store=path=/mnt/disk1
--store=path=/mnt/disk2  # New store

# Start node
systemctl start cockroach
```

---

### 7.2 Upgrades

**ROLLING UPGRADES**

PROCESS:
```bash
# For each node:
1. Stop node: systemctl stop cockroach
2. Replace binary: cp new-cockroach /usr/local/bin/
3. Start node: systemctl start cockroach
4. Wait for node healthy
5. Proceed to next node
```

MONITORING:
```sql
SELECT node_id, build_tag 
FROM crdb_internal.gossip_nodes;
```

**VERSION COMPATIBILITY**

RULES:
- N and N-1 versions compatible
- Can run mixed versions during upgrade
- Finalize upgrade before next major version

FINALIZATION:
```sql
SET CLUSTER SETTING version = '23.1';
```

CAUTION: Finalization is irreversible!

**BACKWARD/FORWARD SAFETY**

ROLLBACK WINDOW:
- Before finalization: Can rollback
- After finalization: Cannot rollback

SAFETY CHECKS:
- Verify all nodes upgraded
- Test in staging first
- Have backup ready
- Review release notes

**UPGRADE FAILURE RECOVERY**

SCENARIOS:
1. Node fails to start on new version
2. Cluster instability
3. Performance regression

RECOVERY:
```bash
# Rollback individual node
1. Stop problematic node
2. Restore previous binary
3. Start node
4. Investigate issue
```

---

### 7.3 Capacity Management

**STORAGE GROWTH PLANNING**

MONITORING:
```sql
SELECT store_id, capacity, available, used 
FROM crdb_internal.kv_store_status;
```

FORECASTING:
- Track growth rate
- Plan for 2-3x headroom
- Alert at 80% capacity
- Add nodes/storage before full

**RANGE COUNT TUNING**

OPTIMAL RANGE SIZE: 512MB (default)

CONSIDERATIONS:
- Too many small ranges: Overhead
- Too few large ranges: Hotspots

ADJUSTMENT:
```sql
-- Change range size
SET CLUSTER SETTING kv.range_max_bytes = 536870912;  -- 512MB
```

**REPLICA PLACEMENT POLICIES**

ZONE CONFIGURATION:
```sql
ALTER TABLE users CONFIGURE ZONE USING 
  num_replicas = 5,
  constraints = '{"+region=us-east": 2, "+region=us-west": 2, "+region=eu": 1}';
```

GOALS:
- Fault tolerance
- Latency optimization
- Compliance
- Cost optimization

---

### 7.4 Performance Tuning

**HOTSPOT MITIGATION**

IDENTIFICATION:
- Hot ranges in Admin UI
- Uneven CPU distribution
- High QPS on single range

SOLUTIONS:
1. Range splits
   ```sql
   ALTER TABLE users SPLIT AT VALUES (100), (200), (300);
   ```

2. Schema redesign
   - Avoid monotonic keys
   - Use hash sharding
   - Partition large tables

3. Query optimization
   - Add indexes
   - Reduce transaction scope
   - Batch operations

**INDEX OPTIMIZATION**

BEST PRACTICES:
✓ Index commonly filtered columns
✓ Avoid over-indexing
✓ Use covering indexes
✓ Monitor index usage

COVERING INDEX:
```sql
CREATE INDEX idx_user_email_name ON users(email) STORING (name);
-- Query can be served entirely from index
```

UNUSED INDEXES:
```sql
SELECT * FROM crdb_internal.index_usage_statistics
WHERE total_reads = 0
ORDER BY index_id;
```

**SQL SCHEMA BEST PRACTICES**

PRIMARY KEYS:
✗ Avoid: Sequential IDs (UUID v1, auto-increment)
✓ Prefer: Random UUIDs (UUID v4), composite keys

EXAMPLE:
```sql
-- BAD: Sequential
CREATE TABLE orders (
  id SERIAL PRIMARY KEY  -- Hotspot!
);

-- GOOD: Random UUID
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid()
);

-- GOOD: Hash-sharded
CREATE TABLE orders (
  id INT PRIMARY KEY USING HASH WITH BUCKET_COUNT = 10
);
```

NORMALIZATION:
- Normalize for consistency
- Denormalize for performance (carefully)
- Use materialized views

**WRITE AMPLIFICATION REDUCTION**

CAUSES:
- Frequent updates to same rows
- Large transactions
- Many indexes

MITIGATION:
1. Batch writes
   ```sql
   -- Instead of multiple INSERTs
   INSERT INTO users VALUES (1, 'a'), (2, 'b'), (3, 'c');
   ```

2. Reduce index count
   - Drop unused indexes
   - Combine related indexes

3. Tune GC TTL
   ```sql
   ALTER TABLE high_churn CONFIGURE ZONE USING gc.ttlseconds = 3600;
   ```

---

### 7.5 Day-2 Operations

**HEALTH CHECKS**

AUTOMATED CHECKS:
```bash
#!/bin/bash
# Health check script

# 1. Node liveness
cockroach node status --certs-dir=certs --host=node1:26257

# 2. Replication health
cockroach sql --certs-dir=certs -e "
  SELECT SUM(ranges_underreplicated) FROM crdb_internal.kv_store_status;
"

# 3. Disk capacity
cockroach sql --certs-dir=certs -e "
  SELECT store_id, available/capacity AS pct_free 
  FROM crdb_internal.kv_store_status 
  WHERE available/capacity < 0.2;
"
```

**REGULAR MAINTENANCE TASKS**

DAILY:
- ✓ Check node status
- ✓ Review error logs
- ✓ Monitor disk usage
- ✓ Verify backups completed

WEEKLY:
- ✓ Review slow queries
- ✓ Check replication status
- ✓ Analyze growth trends
- ✓ Test backup restore (sample)

MONTHLY:
- ✓ Review capacity planning
- ✓ Update statistics
- ✓ Security patches
- ✓ Access reviews

QUARTERLY:
- ✓ Full disaster recovery test
- ✓ Performance review
- ✓ Schema optimization
- ✓ Compliance audit

**AUTOMATION STRATEGIES**

INFRASTRUCTURE AS CODE:
- Terraform for cloud resources
- Ansible for configuration
- Kubernetes operators

MONITORING AUTOMATION:
- Prometheus + Grafana
- Automated alerting
- Self-healing scripts

BACKUP AUTOMATION:
```bash
#!/bin/bash
# Daily backup script

DATE=$(date +%Y%m%d)
cockroach sql --certs-dir=certs -e "
  BACKUP DATABASE mydb TO 'latest' IN 's3://backups/mydb';
"
```

**RUNBOOK CREATION**

TEMPLATE:
```markdown
# Runbook: [Operation Name]

## Scenario
What condition triggers this?

## Symptoms
What will you observe?

## Diagnosis
How to confirm the issue?

## Resolution Steps
1. Step-by-step commands
2. Include SQL queries
3. Include bash commands

## Verification
How to confirm resolution?

## Rollback
What to do if resolution fails?

## Escalation
When to escalate? To whom?
```

EXAMPLE RUNBOOKS:
- Node Down Recovery
- Disk Full Response
- Performance Degradation
- Quorum Loss Recovery
- Backup Restore Procedure

---

## APPENDIX

### QUICK REFERENCE

**COMMON SQL COMMANDS**
```sql
-- Cluster health
SHOW CLUSTER SETTING cluster.organization;
SELECT * FROM crdb_internal.gossip_liveness;

-- Jobs
SHOW JOBS;
CANCEL JOB <job_id>;
RESUME JOB <job_id>;

-- Backups
BACKUP DATABASE mydb TO 's3://bucket/backup';
RESTORE DATABASE mydb FROM 's3://bucket/backup';

-- Users & Permissions
CREATE USER myuser;
GRANT SELECT ON TABLE mytable TO myuser;

-- Statistics
CREATE STATISTICS s1 FROM mytable;
SHOW STATISTICS FOR TABLE mytable;
```

**COMMON BASH COMMANDS**
```bash
# Start node
cockroach start --certs-dir=certs --advertise-addr=node1:26257

# Init cluster
cockroach init --certs-dir=certs --host=node1:26257

# SQL shell
cockroach sql --certs-dir=certs --host=node1:26257

# Node status
cockroach node status --certs-dir=certs

# Decommission
cockroach node decommission <node-id> --certs-dir=certs
```

**IMPORTANT CLUSTER SETTINGS**
```sql
-- Replication
ALTER DATABASE mydb CONFIGURE ZONE USING num_replicas = 3;

-- GC TTL
ALTER TABLE mytable CONFIGURE ZONE USING gc.ttlseconds = 90000;

-- Ranges
SET CLUSTER SETTING kv.range_max_bytes = 536870912;

-- Rebalancing
SET CLUSTER SETTING kv.allocator.load_based_rebalancing = 'leases and replicas';
```

### TROUBLESHOOTING CHECKLIST

**Node Won't Start:**
- [ ] Check disk space
- [ ] Verify certificates
- [ ] Review logs for errors
- [ ] Check port availability
- [ ] Verify join list
- [ ] Clock synchronization

**Slow Queries:**
- [ ] Check execution plan
- [ ] Verify index usage
- [ ] Update statistics
- [ ] Review transaction retries
- [ ] Check hot ranges
- [ ] Network latency

**High CPU:**
- [ ] Identify hot ranges
- [ ] Review query patterns
- [ ] Check compaction activity
- [ ] Verify proper indexing
- [ ] Monitor background jobs

**Backup Failures:**
- [ ] Check external storage connectivity
- [ ] Verify credentials
- [ ] Check disk space
- [ ] Review job status
- [ ] Check logs for errors

---

**END OF COMPREHENSIVE COCKROACHDB NOTES**

*This guide covers all 7 chapters with in-depth explanations, examples, and practical commands for database administration.*

