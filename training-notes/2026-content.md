## CockroachDB Administrator Course 

### Module 1: Introduction to CockroachDB

* What is CockroachDB?
* Evolution of Databases
* SQL vs NoSQL vs NewSQL (Distributed SQL)
* Why CockroachDB?
* CockroachDB Features
* Editions (Core, Enterprise, Cloud)
* Use Cases
* Architecture Overview

---
### Module 2: Installation & Environment Setup

* Prerequisites
* Oracle Linux 9 Installation
* Install CockroachDB
* Single-Node Cluster (Insecure)
* Secure vs Insecure Mode
* Single-Node Cluster (Secure)
    * TLS Certificate Architecture
    * Create CA Certificate
    * Create Node Certificate
    * Create Client Certificate
    * Start CockroachDB Service
    * Configure Systemd
    * Configure Firewall
* DB Console
* SQL Client
---

### Module 3: Cockroachdb Distributed Architecture

* Distributed SQL Architecture
* Node Architecture
* Cluster Architecture
* Stores
* Key-Value Layer
* SQL Layer
* DistSQL
* Ranges
* Range Splits
* Range Merges
* Replicas
* Leaseholders
* Gossip Protocol
* Raft Consensus
* Metadata Tables
  
**Hands-on**
  - Explore Internal Metadata
  - Cluster Topology
* Three-Node Cluster Installation
* Cluster Verification
---

### Module 4: Security & User Management

* Users
* Password Policies
* Roles
* Role Hierarchy
* Grants
* Revokes
* RBAC
* Encryption
   - Encryption in Transit
   - Encryption at Rest
* Audit Logs
* Security Best Practices
---

### Module 5: Distributed Storage Internals

#### Storage Engine

* Pebble Storage Engine
* SSTables
* LSM Trees
* MemTables
* WAL
* Write Path
* Read Path

#### MVCC

* MVCC Architecture
* Version Storage
* Garbage Collection
* Closed Timestamps

#### Range Management

* Range Splits
* Range Merges
* Lease Transfers
* Automatic Rebalancing
* Automatic Sharding

#### Replication Internals

* Replica Factor
* Quorum
* Leader Election
* Leaseholder Election
* Failover
---
### Module 6: Backup & Restore

* FULL BACKUPS
* Incremental Backup
* RESTORE
* Scheduled Backups
* Cloud Storage Backups
* Backup Encryption
* Backup Validation
---

### Module 7: Cluster Administration

* Production CheckList
     - https://www.cockroachlabs.com/docs/v26.2/recommended-production-settings
* Cluster Initialization & Settings
     - Overview
          - Horizantal Scaling
          - Vertical Scaling
* Cluster Configuration
* Node Management
     - Adding Node
     - Remoing Node 
* Node Decommission
* Node Recommission
* Cluster Upgrade
* Cluster Health
* Cluster Diagnostics (Manage Long-Running Queries)
* Licensing

---

### Module 8: Monitoring & Observability

* DB Console
* Metrics Dashboards
* Sessions Page
* Health Checks
* Statement & Transactions Page
* Network Page
* Transactions Page
* Jobs Page
* Schedules Page
* Advanced Debug Page
   - License
---
### Module 09: Multi-Region Cluster [AWS (or) GCP (or) Azure]

* Localities
* Regions
* Zones
* Survival Goals
* REGIONAL BY ROW
* REGIONAL BY TABLE
* GLOBAL Tables
* Geo-Partitioning
* Multi-Region SQL
* Latency Optimization
---
### Module 10: Cross-Cluster Replication (HA)

* Physical Replication
   - Overview
   - Configuration & Setup
   - Failover from Primary to Standby
   - Monitoring
* Logical Data Replication
   - Overview
   - Configuration & Setup
   - Monitor Logical Replication
---
### Module 11: Performance Tuning & Troubleshooting

- Transaction Performance
- MVCC Performance
- ACID Performance Considerations
- UPSERT Performance
- IMPORT Performance
- EXPORT Performance
- Index Tuning
- Query Optimization
- Query Optimizer
- Cost-Based Optimizer (CBO)
- Statistics
- Query Plans
- EXPLAIN
- EXPLAIN ANALYZE
- Vectorized Execution
- Session Settings
- Statement Diagnostics
- SQL Activity Monitoring
- Hotspots
- Hot Ranges
- Contention Analysis
- Leaseholder Imbalance
- Slow Queries
- High CPU Usage
- High Memory Usage
- High Latency
- SQL Connection Performance Issues
---

### Module 12: Migration to CockroachDB
* PostgreSQL Compatibility
* Schema Migration
* Data Migration
* Validation
* Cutover Strategy
* Rollback Strategy
* Migration Best Practices
---
## Advanced 
### Module 13: Automation & Kubernetes

* Containers
   - Docker / Podman Desktop

### Kubernetes

* StatefulSets
* Persistent Volumes
* Storage Classes
* Scaling
* Rolling Updates

### Infrastructure as Code & CI/CD

* Terraform
* Ansible (Overview)
* GitHub Actions
* Kubernetes Deployment Automation


 

