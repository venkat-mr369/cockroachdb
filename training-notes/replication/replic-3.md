
SET CLUSTER SETTING enterprise.license = 'crl-0-EODQ6NQGGAQyEH0vajlANUndqwNHF/AFHQ86EJOHfsC09EVVuYk4nCukzvE';

SHOW CLUSTER SETTING enterprise.license;


SHOW CLUSTER SETTING cluster.organization;

SET CLUSTER SETTING cluster.organization = 'ams-colo';
```
PHYSICAL CLUSTER REPLICATION

                         PRIMARY → STANDBY

              MUMBAI                    SINGAPORE
             PRIMARY                     STANDBY
          ─────────────              ─────────────

          10.10.x.x/16                10.30.x.x/16

       Mumbai-3     Mumbai-4      Singapore-8   Singapore-9
          │             │              │             │
          └───────┬─────┘              └──────┬──────┘
                  │                            │
                  │       PCR                  │
                  └────────────────────────────►

      Cluster ID:                    Cluster ID:
      8dad7094-...                   59a90657-...

      Organization: djs-colo         Organization: djs-colo
      Enterprise: YES                Enterprise: YES
```
---Absolutely. 👍 We'll keep it **100% manual and step-by-step** for now. No scripts, no folder structure, no automation.

We will execute **one step at a time**, verify it, and only then move to the next step.

Your environment is:

```text
Application / Virtual Cluster name:
djs-ams-appconnet

Mumbai PRIMARY
10.10.3.10
10.10.4.10
Cluster ID:
8dad7094-7ab2-4714-beb0-4761682bf978

Singapore STANDBY
10.30.2.151
10.30.2.198
Cluster ID:
59a90657-b21f-462c-8531-3207bcc24f98
```

Both are:

```text
CockroachDB v25.2.2
Enterprise licensed
Organization: djs-colo
2/2 nodes LIVE
```

### Step 1 — Create the application virtual cluster on Mumbai

**Why are we doing this?**

Right now Mumbai only has:

```text
system
```

as the virtual cluster:

```sql
SHOW VIRTUAL CLUSTERS;
```

PCR works with a **virtual cluster**, so first we need an application virtual cluster called:

```text
djs-ams-appconnet
```

We are **not starting replication yet**.

We are only creating the source application virtual cluster on Mumbai.

### Run this on Mumbai

You are connected to:

```text
root@10.10.3.10:26257/defaultdb>
```

Run:

```sql
CREATE VIRTUAL CLUSTER djs-ams-appconnet;
```

### Then immediately verify

```sql
SHOW VIRTUAL CLUSTERS;
```

We want to see something similar to:

```text
id | name               | data_state | service_mode
---+--------------------+------------+-------------
1  | system             | ready      | shared
2  | djs-ams-appconnet  | ready      | ...
```

**Stop after this.**

Don't create anything on Singapore yet.

Don't run `CREATE ... FROM REPLICATION`.

Don't run `cockroach init`.

Just execute:

```sql
CREATE VIRTUAL CLUSTER "djs-ams-appconnet";
```

and then:

```sql
SHOW VIRTUAL CLUSTERS;
```

---
Perfect. This succeeded. ✅ And the output is exactly what we wanted.

```text
id | name               | data_state | service_mode
---+--------------------+------------+------------
1  | system             | ready      | shared
3  | djs-ams-appconnet  | ready      | none
```

Now let me explain **`system` vs `djs-ams-appconnet`**, because this is important for understanding PCR.

### 1. What is `system`?

`system` is the **system virtual cluster**.

Think of your Mumbai physical CockroachDB cluster as the building:

```text
Mumbai Physical Cluster
Cluster ID:
8dad7094-7ab2-4714-beb0-4761682bf978
│
├── Node 1 → 10.10.3.10
├── Node 2 → 10.10.4.10
│
├── system virtual cluster
│
└── djs-ams-appconnet virtual cluster
```

The `system` virtual cluster is created automatically when you initialize CockroachDB.

It manages **cluster-level/system functionality and metadata**. It is not the application workload virtual cluster we're creating for this PCR exercise.

That's why we leave it alone.

### 2. What is `djs-ams-appconnet`?

This is the virtual cluster **we created for your application workload**.

```text
djs-ams-appconnet
        │
        ├── databases
        ├── tables
        ├── application data
        └── PCR source
```

Eventually our topology will be:

```text
              MUMBAI
             PRIMARY
                 │
        Physical Cluster
                 │
        ┌────────┴────────┐
        │                 │
     system        djs-ams-appconnet
                         │
                         │ PCR
                         ▼
                    SINGAPORE
                     STANDBY
                         │
                  djs-ams-appconnet
```

### 3. Why does `system` say `shared`?

You have:

```text
system → service_mode = shared
```

That is expected.

The system virtual cluster is tied to the physical cluster infrastructure and is available as part of the cluster.

Your application virtual cluster shows:

```text
djs-ams-appconnet → service_mode = none
```

That is also important.

It means the virtual cluster exists, but **it is not currently running SQL services**.

We created the virtual cluster, but we haven't started its SQL service yet.

### 4. Current state

So far:

```text
Mumbai Physical Cluster
│
├── system
│     ready
│     shared
│
└── djs-ams-appconnet
      ready
      none
```

This is **not replication yet**.

We haven't touched Singapore.

We haven't created a replication stream.

That's good.

---

# Next step — Start the application virtual cluster

Before we create replication, we need the source virtual cluster to be running.

We need to change:

```text
djs-ams-appconnet
service_mode = none
```

to an active service mode.

First, **don't guess the ALTER syntax**. Your CockroachDB build gives us the exact syntax through `\h`.

At your current SQL prompt, run:

```text
\h ALTER VIRTUAL CLUSTER SERVICE
```

This will show us the exact syntax for changing the service mode.

### Why are we doing this?

Because we want:

```text
djs-ams-appconnet
        │
        ▼
   SQL service running
        │
        ▼
 ready to become PCR PRIMARY
```

Only after that will we configure Singapore as the replicated standby.

**Run only this now:**

```text
\h ALTER VIRTUAL CLUSTER SERVICE
```

Paste the output here. Then I'll explain the `service_mode` options and give you the **exact next command**.


