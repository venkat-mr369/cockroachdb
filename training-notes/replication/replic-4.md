Perfect. Now the syntax is confirmed for **your exact v25.2.2 build**. We can proceed carefully.

Your current state is:

```text
Mumbai physical cluster
├── system
│   └── service_mode = shared
│
└── djs-ams-appconnet
    └── service_mode = none
```

### Why `system` is `shared`

The `system` virtual cluster is the cluster's infrastructure/control virtual cluster. Its service is shared with the physical cluster, so you normally **do not stop or alter it for this PCR exercise**.

Your application VC is different:

```text
djs-ams-appconnet
service_mode = none
```

We created it, but its SQL service isn't running yet.

### Why we need to start it

Our intended flow is:

```text
Mumbai
   │
   ├── system                  ← leave alone
   │
   └── djs-ams-appconnet       ← application VC
              │
              │ PRIMARY
              ▼
          PCR stream
              │
              ▼
Singapore
   └── djs-ams-appconnet       ← standby
```

Your help output gives us two ways to run the application VC:

```text
START SERVICE EXTERNAL
START SERVICE SHARED
```

For our PCR setup, **we should use `EXTERNAL`**, because the application virtual cluster needs its own SQL service rather than sharing the system cluster's SQL service.

### Step 2 — Start `djs-ams-appconnet` on Mumbai

Run exactly:

```sql
ALTER VIRTUAL CLUSTER "djs-ams-appconnet" START SERVICE EXTERNAL;
```

You should get:

```text
ALTER VIRTUAL CLUSTER
```

### Step 3 — Verify

Immediately run:

```sql
SHOW VIRTUAL CLUSTERS;
```

We want to see:

```text
id |       name        | data_state | service_mode
---+-------------------+------------+-------------
1  | system            | ready      | shared
3  | djs-ams-appconnet | ready      | external
```

The important change is:

```text
none
 ↓
external
```

### Don't do anything on Singapore yet

At this stage:

```text
Mumbai
system                 shared       ← leave it
djs-ams-appconnet      external     ← PRIMARY candidate

Singapore
system                 shared       ← leave it
```

We are **not replicating yet**.

We're just getting the Mumbai application VC ready.

Run these two commands:

```sql
ALTER VIRTUAL CLUSTER "djs-ams-appconnet" START SERVICE EXTERNAL;
```

then:

```sql
SHOW VIRTUAL CLUSTERS;
```

Paste the output. Then we'll move to the **Singapore side**, and I'll explain why we configure it differently for the standby.
