## CockroachDB DBA Course (35 Days)

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

## Module 4: SQL Fundamentals

* Databases
* Schemas
* Tables
* Data Types
* Constraints
* Primary Keys
* Secondary Indexes
* Unique Indexes
* Computed Columns
* Sequences
* Views
* Transactions
* ACID Properties
* UPSERT
* IMPORT
* EXPORT

---

# Module 5: Distributed Storage Internals

### Storage Engine

* Pebble Storage Engine
* SSTables
* LSM Trees
* MemTables
* WAL
* Write Path
* Read Path

### MVCC

* MVCC Architecture
* Version Storage
* Garbage Collection
* Closed Timestamps

### Range Management

* Range Splits
* Range Merges
* Lease Transfers
* Automatic Rebalancing
* Automatic Sharding

### Replication Internals

* Replica Factor
* Quorum
* Leader Election
* Leaseholder Election
* Failover
* Replica Recovery

---

# Module 6: Database Administration

### Database Objects

* Databases
* Schemas
* Tables
* Constraints
* Sequences
* Views

### User Administration

* Users
* Roles
* Role Hierarchy
* Grants
* Revokes
* RBAC
* Default Privileges

### Multi-Tenancy

* Tenant Architecture
* Logical Separation
* Resource Isolation

**Hands-on**

* User Management
* Database Administration

---

# Module 7: Cluster Administration

* Cluster Initialization
* Cluster Settings
* Cluster Configuration
* Node Management
* Node Decommission
* Node Recommission
* Cluster Upgrade
* Cluster Health
* Licensing
* Locality Configuration
* Cluster Diagnostics

---

# Module 8: Performance Tuning

* MVCC Performance
* EXPLAIN
* EXPLAIN ANALYZE
* Query Optimizer
* Statistics
* Cost-Based Optimization
* Query Plans
* Index Design
* Session Settings
* Vectorized Execution
* Statement Diagnostics
* SQL Activity
* Hotspots
* Contention Analysis

---

# Module 9: Backup & Restore

* BACKUP
* BACKUP INTO
* Incremental Backup
* RESTORE
* Scheduled Backups
* Cloud Storage Backups
* Backup Encryption
* Disaster Recovery
* Validation

---

# Module 10: Monitoring & Observability

* DB Console
* Metrics
* Logs
* Health Checks
* Events
* Prometheus
* Grafana
* Alerting
* Capacity Monitoring
* SQL Activity
* Slow Queries
* crdb_internal Tables

---

# Module 11: High Availability & Replication

* Replication
* Replica Placement
* Quorum
* Leaseholders
* Lease Transfer
* Node Failure
* Replica Recovery
* Rebalancing
* Network Partition
* Locality
* Zone Configurations
* Failover Demonstration

---

# Module 12: Scaling CockroachDB

* Horizontal Scaling
* Vertical Scaling
* Adding Nodes
* Removing Nodes
* Automatic Rebalancing
* Capacity Planning
* Cluster Expansion
* Rolling Upgrades
* Online Scaling

---

# Module 13: Multi-Region Deployment

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

# Module 14: Security

* Authentication
* Authorization
* TLS Certificates
* Certificate Rotation
* Certificate Renewal
* SQL Users
* Password Policies
* RBAC
* Encryption in Transit
* Encryption at Rest
* Audit Logs
* Security Best Practices

---

# Module 15: Troubleshooting

* Node Down
* Cluster Down
* Disk Full
* High CPU
* High Memory
* High Latency
* Slow Queries
* Hot Ranges
* Leaseholder Imbalance
* Replica Problems
* Clock Skew
* Certificate Expiry
* Network Partition
* Backup Failures
* SQL Connection Problems

---

# Module 16: Production Best Practices

* Production Architecture
* Hardware Sizing
* CPU Recommendations
* Memory Recommendations
* Storage Recommendations
* Filesystem Recommendations
* Backup Strategy
* Monitoring Strategy
* Security Checklist
* Upgrade Strategy
* Maintenance Windows
* Disaster Recovery Planning

---

# Module 17: Automation & Kubernetes

### Containers

* Docker
* Podman Desktop

### Kubernetes

* StatefulSets
* Persistent Volumes
* Storage Classes
* Scaling
* Rolling Updates

### Infrastructure as Code

* Terraform
* Ansible (Overview)

### CI/CD

* GitHub Actions
* Kubernetes Deployment Automation

---

# Module 18: Migration to CockroachDB

* PostgreSQL Compatibility
* Schema Migration
* Data Migration
* Validation
* Cutover Strategy
* Rollback Strategy
* Migration Best Practices

---

# Module 19: Enterprise Features

* Enterprise Licensing
* Scheduled Backups
* Changefeeds
* Row-Level TTL
* Multi-Region Enterprise Features
* Backup to Cloud Storage
* Enterprise Security Features

---

# Module 20: DBA Interview Questions & Real-Time Scenarios

### Architecture Scenarios

* Cluster Design
* Range Distribution
* Leaseholder Placement

### High Availability Scenarios

* Node Failure
* Quorum Loss
* Network Partition
* Failover

### Performance Scenarios

* Slow Queries
* High CPU
* Hotspots
* Contention

### Administration Scenarios

* Backup Failures
* Certificate Expiry
* Cluster Upgrade
* Node Replacement

### Production Case Studies

* Banking
* E-Commerce
* SaaS
* Financial Services
* Multi-Region Deployments

---

#at production DBAs and SREs are expected to know.
