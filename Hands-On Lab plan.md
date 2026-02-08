
 **step-by-step, production-style Hands-On Lab plan for CockroachDB Foundations**, designed exactly like a **DBA / SRE lab** .

Demo:- **on laptops (VMs) or cloud VMs** on **3 nodes** first, then we scale.

---

# 🧪 CockroachDB Foundations – Hands-On Labs

![Image](https://www.cockroachlabs.com/docs/images/cockroachcloud/advanced-architecture.png)

![Image](https://images.ctfassets.net/00voh0j35590/4THzwS4EXJSwSPWz0wwHhD/5c316e338b1526f22541b2d9a26d20f7/pcr-cross-cluster-replication-example.png)

![Image](https://upcloud.com/media/cockroachdb-web-ui-overview.png)

![Image](https://images.ctfassets.net/00voh0j35590/6ACXWZ3JlEpXtWDy1ZXQUH/b1914d1f5745e768254db652eabeaae5/06_cockroachdb_console_transactions.png)

---

## 🔹 Lab Environment Setup

### Lab Topology

| Node   | Hostname | IP (example)  |
| ------ | -------- | ------------- |
| Node 1 | crdb1    | 192.168.10.11 |
| Node 2 | crdb2    | 192.168.10.12 |
| Node 3 | crdb3    | 192.168.10.13 |

**OS**: Oracle Linux / RHEL / Ubuntu
**Ports**: `26257` (SQL), `8080` (Admin UI)

---

## 🧪 LAB 1: Install CockroachDB & Bootstrap Cluster

### Objective

* Install CRDB
* Start secure cluster
* Validate Raft replication

### Steps

1. Download binary on all nodes
2. Create directories:

   * data
   * certs
3. Generate CA, node & client certs
4. Start first node (cluster init)
5. Join remaining nodes
6. Validate:

   * `cockroach node status`
   * Admin UI access

### Outcome

✅ 3-node cluster
✅ Replication factor = 3
✅ Secure mode enabled

---

## 🧪 LAB 2: SQL & Data Distribution

### Objective

Understand how data spreads across nodes.

### Tasks

* Create database & tables
* Insert sample data
* Observe range splits
* Identify leaseholders

### Exercises

* Create table with primary key
* Insert 1M rows
* View:

  * Range count per node
  * Leaseholder distribution
* Manually relocate ranges

### Outcome

✅ Clear understanding of **ranges & replicas**
✅ Why CRDB scales horizontally

---

## 🧪 LAB 3: Failure Testing (Real Power of CRDB)

![Image](https://www.cockroachlabs.com/docs/images/v24.1/decommission-scenario1.2.png)

![Image](https://images.ctfassets.net/00voh0j35590/4ODaYA0wxiSUGWS4voFMC8/ab85f142e34fa89e6631041c91d75633/Cockroach_Labs_Distributed_DB_Architecture_Table_Data.gif)

![Image](https://images.ctfassets.net/00voh0j35590/17HLtUDFbELH2kmJuUJWyA/42f109573e138bbb753ea795752317f1/crdb-tigera-diagram02.jpg)

### Objective

See how CRDB survives failures.

### Tasks

* Stop one node
* Run reads & writes
* Observe Raft quorum behavior
* Restart node

### Advanced

* Kill leaseholder node
* Watch automatic lease transfer

### Outcome

✅ Zero manual failover
✅ Strong consistency confirmed

---

## 🧪 LAB 4: Jobs & Background Tasks

### Objective

Work with CRDB job framework.

### Tasks

* Run schema change
* Create index on large table
* Monitor job status
* Cancel & resume job

### Exercises

* Query `system.jobs`
* Simulate job failure
* Understand retry behavior

### Outcome

✅ Comfortable with **long-running distributed jobs**

---

## 🧪 LAB 5: Security & Access Control

### Objective

Implement enterprise-grade security.

### Tasks

* Create users & roles
* Assign privileges
* Test certificate vs password auth
* Enforce least privilege

### Exercises

* Read-only user
* Application user
* Admin role separation

### Outcome

✅ Production-ready RBAC model

---

## 🧪 LAB 6: Backup & Restore (Most Important for DBAs)

![Image](https://images.ctfassets.net/00voh0j35590/40YlKM5SYGs9JXQ1YtTM2r/f5744f0b080440cfe5c7e5ff07d52aa0/Disaster_Recovery_with_CockroachDB.png)

### Objective

Design disaster recovery.

### Tasks

* Full cluster backup
* Incremental backup
* Table-level restore
* Point-in-time restore

### Advanced

* Simulate data loss
* Restore to new cluster

### Outcome

✅ DR confidence
✅ PITR mastery

---

## 🧪 LAB 7: Monitoring & Alerting

### Objective

Observe cluster health like SREs.

### Tasks

* Explore Admin UI dashboards
* Identify hot ranges
* Enable Prometheus metrics
* Create basic alerts

### Metrics to Watch

* Raft latency
* Replica under-replication
* Disk usage
* SQL retry rate

### Outcome

✅ Early problem detection skills

---

## 🧪 LAB 8: Diagnostics & Debugging

### Objective

Fix real production issues.

### Scenarios

* Slow query
* Transaction contention
* Hotspot range
* Disk pressure

### Tools

* SQL EXPLAIN ANALYZE
* Traces
* Logs
* Event viewer

### Outcome

✅ Root cause analysis ability

---

## 🧪 LAB 9: Cluster Maintenance (Day-2 Operations)

![Image](https://user-images.githubusercontent.com/4730669/120014337-efe6e280-bfaf-11eb-94c6-a3273e3210e2.png)

![Image](https://www.cockroachlabs.com/docs/images/cockroachcloud/advanced-architecture.png)

### Objective

Operate CRDB safely in production.

### Tasks

* Add new node
* Decommission old node
* Rolling upgrade
* Disk expansion

### Exercises

* Validate zero downtime
* Monitor rebalancing

### Outcome

✅ True DBA/SRE confidence

---

## 🧪 LAB 10: Capstone Lab 

### Scenario

> Global trading application needs **zero downtime, HA, backups, security, monitoring**

### Tasks

* Secure cluster
* Load test
* Fail nodes
* Restore data
* Upgrade version

### Deliverables

* Architecture diagram
* Runbook
* Incident response steps

---



