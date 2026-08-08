Excellent. ✅ This is exactly the state we wanted.

Your Mumbai cluster now shows:

```text
id |       name        | data_state | service_mode
---+-------------------+------------+-------------
1  | system            | ready      | shared
3  | djs-ams-appconnet | ready      | external
```

### What we have accomplished

```text
Mumbai Physical Cluster
Cluster ID: 8dad7094-7ab2-4714-beb0-4761682bf978
│
├── system
│   └── shared
│
└── djs-ams-appconnet
    ├── ready
    └── external  ✅
```

`djs-ams-appconnet` is now running as an **independent SQL service**, which is what we need for the application virtual cluster.

### Why `EXTERNAL`?

There are two service modes available:

```text
SHARED
EXTERNAL
```

We selected:

```text
EXTERNAL
```

because this application virtual cluster needs its own SQL service endpoint. The `system` virtual cluster continues using:

```text
shared
```

We leave `system` alone.

### Current PCR progress

```text
1. Mumbai cluster created             ✅
2. Singapore cluster created          ✅
3. Both 2/2 nodes LIVE                ✅
4. Same CockroachDB v25.2.2           ✅
5. Enterprise license                 ✅
6. Organization djs-colo               ✅
7. Create application VC              ✅
8. Start application VC               ✅
9. PCR replication                     ⬜ NEXT
```

### Next step — Singapore

Now we move to the **Singapore cluster**.

We are **not going to create a normal virtual cluster there manually**.

Why?

Because the standby/application virtual cluster will eventually be created **from the Mumbai replication source** using:

```text
FROM REPLICATION OF ...
```

That is the important PCR part.

So first, connect to Singapore:

```bash
cockroach sql --insecure --host=10.30.2.151:26257
```

You should see:

```text
Cluster ID:
59a90657-b21f-462c-8531-3207bcc24f98
```

Then run only:

```sql
SHOW VIRTUAL CLUSTERS;
```

We expect currently:

```text
id | name   | data_state | service_mode
---+--------+------------+-------------
1  | system | ready      | shared
```

### Stop there

**Do not create `djs-ams-appconnet` manually on Singapore yet.**

The reason is important:

```text
Mumbai:
djs-ams-appconnet
       │
       │ SOURCE
       ▼
Singapore:
djs-ams-appconnet
       │
       │ created FROM REPLICATION
       ▼
STANDBY
```

We want Singapore's copy to be created through the **PCR mechanism**, not as an unrelated empty virtual cluster.

So connect to:

```text
10.30.2.151:26257
```

and run:

```sql
SHOW VIRTUAL CLUSTERS;
```

Paste the output. Then we'll do the **actual Mumbai → Singapore replication creation step**, and I'll explain every part of that command before you execute it.

Perfect. **Singapore is now ready.** ✅

We have now completed the prerequisite phase on both sides.

### Current state

**Mumbai PRIMARY candidate**

```text
Cluster ID: 8dad7094-7ab2-4714-beb0-4761682bf978
Organization: djs-colo
Version: v25.2.2

10.10.3.10  LIVE
10.10.4.10  LIVE

Virtual clusters:
system              ready / shared
djs-ams-appconnet   ready / external
```

**Singapore STANDBY candidate**

```text
Cluster ID: 59a90657-b21f-462c-8531-3207bcc24f98
Organization: djs-colo
Version: v25.2.2

10.30.2.151  LIVE
10.30.2.198  LIVE

Virtual clusters:
system              ready / shared
```

So the important difference is:

```text
Mumbai                         Singapore
──────                         ─────────
system                         system
djs-ams-appconnet              ← not created manually
    │
    │ PCR
    └────────────────────────────►
```

### Next: establish the PCR relationship

Now we are finally at the **actual replication step**.

But before executing the `CREATE VIRTUAL CLUSTER ... FROM REPLICATION` command, we need to identify the **location syntax** that your v25.2.2 build expects.

Your earlier help showed:

```text
CREATE VIRTUAL CLUSTER [ IF NOT EXISTS ] name [ <replication> ]

Replication option:
FROM REPLICATION OF name ON <location> [ WITH OPTIONS ... ]
```

The remaining unknown is:

```text
ON <location>
```

We should not invent that value.

### Step 1 — Get the exact location syntax

On **Singapore**, run:

```text
\h CREATE VIRTUAL CLUSTER
```

You already saw the abbreviated syntax. Now we want to see whether the help provides more information about `<location>`.

Also run:

```text
\h ALTER VIRTUAL CLUSTER
```

### Step 2 — Check the PCR URI/location mechanisms

On Singapore, run:

```text
\h CREATE VIRTUAL CLUSTER
```

and paste the complete output again if it contains more detail.

If it only gives the same output, that's fine.

### Step 3 — Do not create anything yet

Do **not** run:

```sql
CREATE VIRTUAL CLUSTER "djs-ams-appconnet";
```

on Singapore.

Do **not** run:

```sql
CREATE VIRTUAL CLUSTER ... FROM REPLICATION ...
```

until we confirm the `<location>` syntax.

The reason is that this is the command that actually establishes the **Mumbai → Singapore PCR relationship**, so this is the point where we need to be precise.

Your setup is now clean:

```text
                    PCR

       MUMBAI                         SINGAPORE
       PRIMARY                        STANDBY

  10.10.3.10 ──┐                ┌── 10.30.2.151
  10.10.4.10 ──┤                ├── 10.30.2.198
               │                │
               │                │
      djs-ams-appconnet          │
               │                 │
               └───────►─────────┘
```

**One thing at a time:** run `\h CREATE VIRTUAL CLUSTER` on Singapore and paste the output. Then I'll give you the exact next command and explain every part before you execute it.

Correct. **Do not create anything yet.** 👍

We have confirmed that Singapore's v25.2.2 build has the same PCR syntax:

```sql
CREATE VIRTUAL CLUSTER [ IF NOT EXISTS ] name
FROM REPLICATION OF name ON <location>
[ WITH OPTIONS ... ]
```

But the important part we still need to determine is:

```text
ON <location>
```

I don't want you to guess that value.

### Current state — leave it exactly like this

**Mumbai:**

```text
Physical cluster: 8dad7094-...
system              → shared
djs-ams-appconnet   → external
```

**Singapore:**

```text
Physical cluster: 59a90657-...
system              → shared
```

This is correct.

### Next step: find the `<location>` syntax

While you're on the **Singapore SQL prompt**, run:

```text
\h CREATE VIRTUAL CLUSTER
```

You already did that, and it only shows the placeholder.

So now run:

```text
\h CREATE
```

Look through the output for anything related to:

```text
LOCATION
EXTERNAL CONNECTION
REPLICATION
VIRTUAL CLUSTER
```

If the output is too large, that's fine—paste the relevant part.

### Also run this

```sql
SHOW CREATE VIRTUAL CLUSTER "system";
```

If that syntax isn't supported, **don't worry**—just paste the error.

### And one important point

We don't need to create another virtual cluster on Singapore manually.

The intended flow is:

```text
Mumbai
djs-ams-appconnet
       │
       │  SOURCE
       │
       ▼
   PCR stream
       │
       ▼
Singapore
djs-ams-appconnet
       │
       │  STANDBY
```

The Singapore application VC will be created as part of the **replication configuration**, not as an unrelated empty VC.

So for now:

**No `CREATE VIRTUAL CLUSTER` command. No `init`. No restart.**

Run:

```text
\h CREATE
```

and paste the output relevant to `LOCATION`/`REPLICATION`. We'll identify the correct location syntax first, then I'll give you **one exact command** and explain it before you run it.
