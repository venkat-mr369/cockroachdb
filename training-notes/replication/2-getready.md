Now that both **Mumbai** and **Singapore** are independent 2-node clusters and your Enterprise license is installed, we can move to **Physical Cluster Replication**.

### Verify Enterprise License on Both Clusters

On **Mumbai**:

```sql
SHOW CLUSTER SETTING enterprise.license;
```

On **Singapore**:

```sql
SHOW CLUSTER SETTING enterprise.license;
```

Both should return a non-empty value.

---

### Step 2 - Verify Different Cluster IDs

On Mumbai:

```sql
SELECT crdb_internal.cluster_id();
```

On Singapore:

```sql
SELECT crdb_internal.cluster_id();
```

The IDs **must be different**.

---

### Verify Feature Availability

CockroachDB has changed the Physical Replication SQL syntax across releases, and **v25.2.2 uses the current syntax for its release**. Before issuing replication commands, let's verify exactly which statements your binary supports.

Run these on the **Mumbai cluster**.

### Check 1

```sql
SHOW SYNTAX 'CREATE PHYSICAL REPLICATION STREAM';
```

### Check 2

If the first one says unknown syntax, run:

```sql
SHOW SYNTAX 'CREATE REPLICATION STREAM';
```

### Check 3

If that is also unknown, run:

```sql
SHOW SYNTAX 'CREATE TENANT FROM REPLICATION';
```

### Check 4

Also run:

```sql
SHOW JOBS;
```

---

## Why this step?

CockroachDB has renamed and evolved the replication SQL over recent major versions. I don't want to give you commands from an older release that won't work on v25.2.2.

1. The exact command to create the replication producer on Mumbai.
2. The exact command to start replication on Singapore.
3. Monitoring commands.
4. Failover commands.
5. Failback commands.

