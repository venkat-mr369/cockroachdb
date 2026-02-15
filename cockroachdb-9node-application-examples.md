# 9-Node Multi-Region CockroachDB Cluster — Real-World Application Examples

> 10 detailed real-world applications where a multi-region 9-node CockroachDB cluster (Paris, US-East, Mumbai) is the perfect fit — with architecture diagrams, database schemas, SQL examples, and why each app needs this setup.

---

## Why Does Any App Need 9 Nodes Across 3 Regions?

Before diving into examples, understand the **3 core reasons** why applications need this architecture:

```
  ┌─────────────────────────────────────────────────────────────────┐
  │               WHY MULTI-REGION?                                 │
  │                                                                 │
  │  1. 🌍 LOW LATENCY        Users in Paris, USA & India all      │
  │                            get fast responses (<50ms)           │
  │                                                                 │
  │  2. 🛡️ SURVIVE FAILURES   If entire Paris region goes down,    │
  │                            US-East & Mumbai keep working        │
  │                            (99.999% uptime = 5 min downtime/yr) │
  │                                                                 │
  │  3. 📜 DATA COMPLIANCE    GDPR says EU user data stays in EU   │
  │                            Indian data stays in India           │
  │                            US data stays in US                  │
  └─────────────────────────────────────────────────────────────────┘
```

---

## Application 1: 🏦 Global Digital Banking Platform

### The Business

A digital bank like **Revolut, N26, or Paytm** serving customers in Europe, USA, and India. Customers check balances, transfer money, and pay bills 24/7.

### Why 9-Node Cluster?

```
  PROBLEM WITHOUT MULTI-REGION:
  
  ┌──────────┐                              ┌──────────┐
  │ User in  │ ──── 200ms latency ────────► │ Single   │
  │ Mumbai   │                              │ DB in    │
  │          │ ◄──── 200ms back ──────────  │ Paris    │
  └──────────┘                              └──────────┘
  Total: 400ms per query 😱 (unacceptable for banking)
  
  SOLUTION WITH 9-NODE CLUSTER:
  
  ┌──────────┐                    ┌──────────┐
  │ User in  │ ──── 5ms ────────► │ Mumbai   │
  │ Mumbai   │                    │ Node     │
  │          │ ◄──── 5ms ───────  │ (local!) │
  └──────────┘                    └──────────┘
  Total: 10ms per query ✅ (instant banking experience)
```

### Key Requirements Met

| Requirement | How 9-Node Cluster Solves It |
|---|---|
| **Zero downtime** | If Paris region dies, US & India nodes keep serving |
| **GDPR compliance** | EU customer data stays on Paris nodes |
| **RBI compliance** | Indian customer data stays on Mumbai nodes |
| **ACID transactions** | Money transfers never lose data (strong consistency) |
| **Low latency** | Users always hit the nearest node |

### Database Schema

```sql
-- Create multi-region database
CREATE DATABASE banking;
USE banking;
ALTER DATABASE banking SET PRIMARY REGION "eu-west-3";
ALTER DATABASE banking ADD REGION "us-east-1";
ALTER DATABASE banking ADD REGION "ap-south-1";
ALTER DATABASE banking SURVIVE REGION FAILURE;

-- Accounts table — data stays in user's region
CREATE TABLE accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    customer_name STRING NOT NULL,
    email STRING UNIQUE NOT NULL,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency STRING NOT NULL DEFAULT 'USD',
    status STRING NOT NULL DEFAULT 'active',
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Transactions table — stays in the region where it originated
CREATE TABLE transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    from_account UUID REFERENCES accounts(id),
    to_account UUID REFERENCES accounts(id),
    amount DECIMAL(15,2) NOT NULL,
    currency STRING NOT NULL,
    type STRING NOT NULL,   -- 'transfer', 'deposit', 'withdrawal'
    status STRING NOT NULL DEFAULT 'pending',
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Exchange rates — read everywhere, updated rarely (GLOBAL table)
CREATE TABLE exchange_rates (
    from_currency STRING NOT NULL,
    to_currency STRING NOT NULL,
    rate DECIMAL(10,6) NOT NULL,
    updated_at TIMESTAMP DEFAULT now(),
    PRIMARY KEY (from_currency, to_currency)
) LOCALITY GLOBAL;

-- Example: Transfer money
BEGIN;
UPDATE accounts SET balance = balance - 500.00
    WHERE id = 'sender-uuid' AND region = 'eu-west-3';
UPDATE accounts SET balance = balance + 500.00
    WHERE id = 'receiver-uuid' AND region = 'ap-south-1';
INSERT INTO transactions (from_account, to_account, amount, currency, type, status, region)
    VALUES ('sender-uuid', 'receiver-uuid', 500.00, 'EUR', 'transfer', 'completed', 'eu-west-3');
COMMIT;
```

### Real Companies Using This Pattern
- **Santander** — Global banking on CockroachDB
- **SumUp** — 4M+ merchants across 35 markets
- **FanDuel** — Financial ledger for 13M+ users across 28 US states

---

## Application 2: 🛒 Global E-Commerce Platform

### The Business

An online store like **Amazon, Flipkart, or Zalando** serving customers across Europe, USA, and India with product catalog, shopping carts, orders, and payments.

### Architecture

```
                      GLOBAL E-COMMERCE ARCHITECTURE

  🇫🇷 Europe Users          🇺🇸 US Users              🇮🇳 India Users
       │                        │                         │
       ▼                        ▼                         ▼
  ┌──────────┐           ┌──────────┐              ┌──────────┐
  │  App      │           │  App      │              │  App      │
  │  Server   │           │  Server   │              │  Server   │
  │  Paris    │           │  US-East  │              │  Mumbai   │
  └────┬─────┘           └────┬─────┘              └────┬─────┘
       │                      │                         │
       ▼                      ▼                         ▼
  ┌──────────┐           ┌──────────┐              ┌──────────┐
  │  CockroachDB          │  CockroachDB             │  CockroachDB
  │  Paris Nodes│          │  US Nodes  │             │  Mumbai Nodes
  │  (3 nodes) │          │  (3 nodes) │             │  (3 nodes)│
  └──────────┘           └──────────┘              └──────────┘
       │                      │                         │
       └──────────────────────┼─────────────────────────┘
                    Automatic Replication
                    
  TABLES:
  ┌──────────────────────────────────────────────────────────┐
  │ products        → GLOBAL (read everywhere, same catalog) │
  │ categories      → GLOBAL (same categories worldwide)     │
  │ users           → REGIONAL BY ROW (user data stays local)│
  │ orders          → REGIONAL BY ROW (order stays in region)│
  │ shopping_carts  → REGIONAL BY ROW (cart stays local)     │
  │ inventory       → REGIONAL BY ROW (stock per warehouse)  │
  │ payments        → REGIONAL BY ROW (payment stays local)  │
  └──────────────────────────────────────────────────────────┘
```

### Why 9-Node Cluster?

| Scenario | Single Region Problem | Multi-Region Solution |
|---|---|---|
| **Black Friday sale** | 1 region overloaded, crashes | Load distributed across 9 nodes in 3 regions |
| **Paris datacenter fire** | Entire website down | US & India nodes serve European users (slower but alive) |
| **Product catalog read** | 200ms from India to Paris | GLOBAL table = instant reads everywhere |
| **Indian user places order** | Order data crosses ocean | REGIONAL BY ROW = data stays in Mumbai |

### Database Schema

```sql
CREATE DATABASE ecommerce;
USE ecommerce;
ALTER DATABASE ecommerce SET PRIMARY REGION "us-east-1";
ALTER DATABASE ecommerce ADD REGION "eu-west-3";
ALTER DATABASE ecommerce ADD REGION "ap-south-1";
ALTER DATABASE ecommerce SURVIVE REGION FAILURE;

-- Products — everyone reads, rarely written (GLOBAL)
CREATE TABLE products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name STRING NOT NULL,
    description STRING,
    price DECIMAL(10,2) NOT NULL,
    category_id UUID,
    image_url STRING,
    is_active BOOL DEFAULT true
) LOCALITY GLOBAL;

-- Users — data stays in their region
CREATE TABLE users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name STRING NOT NULL,
    email STRING UNIQUE NOT NULL,
    address JSONB,
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Orders — stays in the region where placed
CREATE TABLE orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    status STRING DEFAULT 'pending',
    items JSONB NOT NULL,
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Inventory — per warehouse per region
CREATE TABLE inventory (
    product_id UUID NOT NULL,
    warehouse_region crdb_internal_region NOT NULL,
    quantity INT NOT NULL DEFAULT 0,
    reserved INT NOT NULL DEFAULT 0,
    PRIMARY KEY (product_id, warehouse_region)
) LOCALITY REGIONAL BY ROW AS warehouse_region;
```

### Real Companies Using This Pattern
- **Global electronics retailer** — 20+ microservices on CockroachDB (catalog, cart, POS)
- **Shopmonkey** — Geo-distributed auto-repair shop management
- **DoorDash** — Order management across US regions

---

## Application 3: 💳 Global Payment Processing System

### The Business

A payment gateway like **Stripe, Razorpay, or Adyen** that processes credit card and UPI payments for merchants worldwide.

### Why 9 Nodes?

```
  PAYMENT PROCESSING REQUIREMENTS:
  
  ✦ Process payments in < 100ms (user waiting at checkout)
  ✦ NEVER lose a payment record (financial compliance)
  ✦ NEVER process same payment twice (idempotency)
  ✦ Available 24/7/365 (someone is always paying)
  ✦ PCI-DSS compliance (data residency rules)
  
  HOW 9-NODE CLUSTER DELIVERS:
  
  Payment in Paris ──► Paris Node (10ms) ──► Replicated to US & Mumbai
                                              (async, for disaster recovery)
  
  If Paris nodes fail:
  Payment in Paris ──► US-East Node (80ms) ──► Still works!
                                                (slightly slower but ALIVE)
```

### Database Schema

```sql
CREATE DATABASE payments;
USE payments;
ALTER DATABASE payments SET PRIMARY REGION "us-east-1";
ALTER DATABASE payments ADD REGION "eu-west-3";
ALTER DATABASE payments ADD REGION "ap-south-1";
ALTER DATABASE payments SURVIVE REGION FAILURE;

-- Merchants
CREATE TABLE merchants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name STRING NOT NULL,
    api_key STRING UNIQUE NOT NULL,
    webhook_url STRING,
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Payment transactions — idempotent, region-local
CREATE TABLE payment_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    idempotency_key STRING UNIQUE NOT NULL,  -- prevents double-charge
    merchant_id UUID NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    currency STRING NOT NULL,
    card_last_four STRING,
    status STRING NOT NULL DEFAULT 'initiated',
    -- 'initiated' → 'processing' → 'completed' / 'failed'
    gateway_response JSONB,
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Settlement records
CREATE TABLE settlements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID NOT NULL,
    total_amount DECIMAL(15,2) NOT NULL,
    currency STRING NOT NULL,
    transaction_count INT NOT NULL,
    settled_at TIMESTAMP DEFAULT now(),
    region crdb_internal_region NOT NULL
) LOCALITY REGIONAL BY ROW AS region;

-- Process a payment (idempotent)
INSERT INTO payment_transactions
    (idempotency_key, merchant_id, amount, currency, card_last_four, status, region)
VALUES
    ('pay_abc123', 'merchant-uuid', 49.99, 'EUR', '4242', 'completed', 'eu-west-3')
ON CONFLICT (idempotency_key) DO NOTHING;  -- prevents double-charge
```

---

## Application 4: 🎮 Online Multiplayer Gaming Platform

### The Business

A gaming platform like **FanDuel, DraftKings, or Dream11** with real-money gaming, leaderboards, and player wallets.

### Architecture

```
  GAMING PLATFORM MULTI-REGION ARCHITECTURE

  🇪🇺 European Players     🇺🇸 US Players          🇮🇳 Indian Players
  (Fantasy Football)       (Sports Betting)        (Cricket Fantasy)
       │                        │                        │
       ▼                        ▼                        ▼
  ┌──────────┐           ┌──────────┐             ┌──────────┐
  │ Game     │           │ Game     │             │ Game     │
  │ Server   │           │ Server   │             │ Server   │
  │ Paris    │           │ US-East  │             │ Mumbai   │
  └────┬─────┘           └────┬─────┘             └────┬─────┘
       │                      │                        │
       ▼                      ▼                        ▼
  ┌──────────────────────────────────────────────────────────┐
  │              CockroachDB 9-Node Cluster                  │
  │                                                          │
  │  REGIONAL BY ROW:           GLOBAL:                      │
  │  • player_wallets           • game_rules                 │
  │  • bets / entries           • leaderboard_config         │
  │  • match_results            • prize_structures           │
  │  • player_profiles          • sports_schedules           │
  └──────────────────────────────────────────────────────────┘
  
  WHY THIS MATTERS:
  ┌────────────────────────────────────────────────────────────┐
  │ 🏈 Super Bowl: 1000s of bets/second spike in US-East      │
  │ ⚽ UEFA Final: 1000s of bets/second spike in Paris         │
  │ 🏏 IPL Match: 1000s of entries/second spike in Mumbai     │
  │                                                            │
  │ Each region handles its own spike locally!                 │
  │ Other regions are not affected.                            │
  └────────────────────────────────────────────────────────────┘
```

### Why 9 Nodes?

| Scenario | Why Multi-Region |
|---|---|
| **IPL match in India** | Mumbai nodes handle 10K bets/sec locally without affecting Paris or US |
| **Super Bowl in US** | US-East nodes handle the spike, Mumbai/Paris serve normally |
| **US gambling law** | Betting data MUST stay in the state/country where bet was placed (Wire Act) |
| **Wallet balance check** | Player always reads from nearest node (5ms, not 200ms) |
| **Real money involved** | Cannot lose a bet record — ACID transactions across 9 nodes |

### Database Schema

```sql
CREATE DATABASE gaming;
USE gaming;
ALTER DATABASE gaming SET PRIMARY REGION "us-east-1";
ALTER DATABASE gaming ADD REGION "eu-west-3";
ALTER DATABASE gaming ADD REGION "ap-south-1";
ALTER DATABASE gaming SURVIVE REGION FAILURE;

-- Player wallets — money MUST stay in player's region
CREATE TABLE player_wallets (
    player_id UUID PRIMARY KEY,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    currency STRING NOT NULL,
    region crdb_internal_region NOT NULL
) LOCALITY REGIONAL BY ROW AS region;

-- Bets / Fantasy entries — must stay where placed
CREATE TABLE bets (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    player_id UUID NOT NULL,
    match_id UUID NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    odds DECIMAL(8,4),
    selection JSONB NOT NULL,
    status STRING DEFAULT 'open',
    -- 'open' → 'won' / 'lost' / 'cancelled'
    payout DECIMAL(10,2),
    region crdb_internal_region NOT NULL,
    placed_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Game rules and prize structures — read everywhere
CREATE TABLE game_rules (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    game_type STRING NOT NULL,
    rules JSONB NOT NULL,
    prize_structure JSONB NOT NULL,
    updated_at TIMESTAMP DEFAULT now()
) LOCALITY GLOBAL;

-- Place a bet (transactional — deduct wallet + create bet atomically)
BEGIN;
UPDATE player_wallets SET balance = balance - 100.00
    WHERE player_id = 'player-uuid' AND region = 'ap-south-1';
INSERT INTO bets (player_id, match_id, amount, odds, selection, region)
    VALUES ('player-uuid', 'ipl-match-uuid', 100.00, 2.5,
            '{"team": "Mumbai Indians", "type": "match_winner"}', 'ap-south-1');
COMMIT;
```

### Real Company: FanDuel
- **13M+ active players** across 28 US states
- Financial ledger system on CockroachDB
- Handles Super Bowl traffic spikes (thousands of bets per second)
- Deployed across AWS Regional Data Centers + AWS Outposts + AWS Local Zones

---

## Application 5: 🚗 Global Ride-Sharing / Delivery Platform

### The Business

A service like **Uber, Ola, or Bolt** operating in multiple countries, matching drivers with riders in real-time.

### Architecture

```
  RIDE-SHARING MULTI-REGION DATA FLOW

  Paris: 50,000 rides/day     US: 500,000 rides/day     Mumbai: 200,000 rides/day
       │                            │                          │
       ▼                            ▼                          ▼
  ┌──────────┐              ┌──────────┐               ┌──────────┐
  │ Paris    │              │ US-East  │               │ Mumbai   │
  │ Nodes   │              │ Nodes    │               │ Nodes    │
  │          │              │          │               │          │
  │ • Rides in Paris        │ • Rides in US             │ • Rides in India
  │ • Paris drivers         │ • US drivers              │ • India drivers
  │ • Paris pricing         │ • US pricing              │ • India pricing
  └──────────┘              └──────────┘               └──────────┘
       │                         │                          │
       └─────────────────────────┼──────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │     GLOBAL TABLES       │
                    │ • vehicle_types         │
                    │ • service_configs       │
                    │ • surge_algorithms      │
                    └─────────────────────────┘
```

### Database Schema

```sql
CREATE DATABASE rideshare;
USE rideshare;
ALTER DATABASE rideshare SET PRIMARY REGION "us-east-1";
ALTER DATABASE rideshare ADD REGION "eu-west-3";
ALTER DATABASE rideshare ADD REGION "ap-south-1";
ALTER DATABASE rideshare SURVIVE REGION FAILURE;

-- Drivers — always in their operating region
CREATE TABLE drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name STRING NOT NULL,
    phone STRING UNIQUE NOT NULL,
    vehicle_type STRING NOT NULL,
    current_lat DECIMAL(10,7),
    current_lng DECIMAL(10,7),
    status STRING DEFAULT 'offline',
    -- 'offline', 'available', 'on_trip'
    rating DECIMAL(3,2) DEFAULT 5.00,
    region crdb_internal_region NOT NULL
) LOCALITY REGIONAL BY ROW AS region;

-- Rides — always local to where the ride happens
CREATE TABLE rides (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    rider_id UUID NOT NULL,
    driver_id UUID,
    pickup_lat DECIMAL(10,7) NOT NULL,
    pickup_lng DECIMAL(10,7) NOT NULL,
    dropoff_lat DECIMAL(10,7),
    dropoff_lng DECIMAL(10,7),
    status STRING DEFAULT 'requested',
    fare DECIMAL(10,2),
    surge_multiplier DECIMAL(4,2) DEFAULT 1.00,
    region crdb_internal_region NOT NULL,
    requested_at TIMESTAMP DEFAULT now(),
    completed_at TIMESTAMP
) LOCALITY REGIONAL BY ROW AS region;

-- Vehicle types & pricing — read everywhere
CREATE TABLE service_configs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    vehicle_type STRING NOT NULL,
    base_fare DECIMAL(10,2),
    per_km_rate DECIMAL(10,2),
    per_min_rate DECIMAL(10,2),
    config JSONB,
    updated_at TIMESTAMP DEFAULT now()
) LOCALITY GLOBAL;
```

---

## Application 6: 📺 Global Video Streaming Platform

### The Business

A streaming service like **Netflix, Hotstar, or Canal+** managing user profiles, watch history, subscriptions, and content metadata globally.

### Why 9 Nodes?

| Data Type | Table Locality | Reason |
|---|---|---|
| **User profiles** | REGIONAL BY ROW | User data stays in their country (GDPR) |
| **Watch history** | REGIONAL BY ROW | Millions of rows, must be fast to query locally |
| **Subscriptions** | REGIONAL BY ROW | Payment data stays in region |
| **Content catalog** | GLOBAL | Same movies/shows available everywhere, read-heavy |
| **Content metadata** | GLOBAL | Genres, actors, descriptions — rarely changes |
| **Recommendations** | REGIONAL BY ROW | Personalized per user, computed in their region |

### Database Schema

```sql
CREATE DATABASE streaming;
USE streaming;
ALTER DATABASE streaming SET PRIMARY REGION "us-east-1";
ALTER DATABASE streaming ADD REGION "eu-west-3";
ALTER DATABASE streaming ADD REGION "ap-south-1";
ALTER DATABASE streaming SURVIVE REGION FAILURE;

-- Content catalog — same everywhere, read millions of times
CREATE TABLE content (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title STRING NOT NULL,
    description STRING,
    type STRING NOT NULL, -- 'movie', 'series', 'documentary'
    genres STRING[] NOT NULL,
    duration_minutes INT,
    release_year INT,
    thumbnail_url STRING,
    stream_url STRING NOT NULL,
    is_active BOOL DEFAULT true
) LOCALITY GLOBAL;

-- User profiles — GDPR requires EU data in EU
CREATE TABLE user_profiles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name STRING NOT NULL,
    email STRING UNIQUE NOT NULL,
    subscription_plan STRING DEFAULT 'free',
    preferences JSONB,
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Watch history — billions of rows, always queried locally
CREATE TABLE watch_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    content_id UUID NOT NULL,
    watched_seconds INT NOT NULL DEFAULT 0,
    total_seconds INT NOT NULL,
    completed BOOL DEFAULT false,
    region crdb_internal_region NOT NULL,
    watched_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- "Continue watching" — fast local query
SELECT c.title, c.thumbnail_url, w.watched_seconds, w.total_seconds
FROM watch_history w
JOIN content c ON w.content_id = c.id
WHERE w.user_id = 'user-uuid'
  AND w.region = 'eu-west-3'
  AND w.completed = false
ORDER BY w.watched_at DESC
LIMIT 10;
```

---

## Application 7: 🏥 Global Healthcare / Telemedicine Platform

### The Business

A telemedicine platform like **Practo, Teladoc, or Doctolib** connecting patients with doctors across countries, storing medical records with strict data residency requirements.

### Why 9 Nodes? (Data Compliance is CRITICAL)

```
  HEALTHCARE DATA REGULATIONS:
  
  🇪🇺 GDPR (Europe)
  ├── Patient data MUST stay in EU
  ├── Right to be deleted
  └── Strict access controls
  
  🇺🇸 HIPAA (USA)
  ├── Patient health info (PHI) protected
  ├── Audit trail required
  └── Encryption mandatory
  
  🇮🇳 DPDPA (India)
  ├── Personal data localization
  ├── Consent management
  └── Data processing restrictions
  
  SOLUTION: REGIONAL BY ROW
  EU patient data → Paris nodes ONLY
  US patient data → US-East nodes ONLY
  India patient data → Mumbai nodes ONLY
  
  CockroachDB enforces this at the database level!
```

### Database Schema

```sql
-- Patient records — NEVER leave their region
CREATE TABLE patients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name STRING NOT NULL,
    date_of_birth DATE NOT NULL,
    blood_group STRING,
    allergies STRING[],
    medical_history JSONB,
    insurance_id STRING,
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Appointments — local to patient's region
CREATE TABLE appointments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    patient_id UUID NOT NULL,
    doctor_id UUID NOT NULL,
    appointment_type STRING NOT NULL, -- 'video', 'in-person', 'chat'
    scheduled_at TIMESTAMP NOT NULL,
    status STRING DEFAULT 'scheduled',
    notes STRING,
    prescription JSONB,
    region crdb_internal_region NOT NULL
) LOCALITY REGIONAL BY ROW AS region;

-- Doctors directory — available globally
CREATE TABLE doctors (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name STRING NOT NULL,
    specialization STRING NOT NULL,
    languages STRING[] NOT NULL,
    consultation_fee DECIMAL(10,2),
    rating DECIMAL(3,2),
    available_hours JSONB
) LOCALITY GLOBAL;
```

---

## Application 8: 📊 Global Stock Trading Platform

### The Business

A trading platform like **Zerodha, Robinhood, or eToro** where users buy/sell stocks, crypto, and options. Your interest area!

### Why 9 Nodes?

```
  STOCK TRADING REQUIREMENTS vs 9-NODE SOLUTION:
  
  ┌──────────────────────────┬─────────────────────────────────────┐
  │ Requirement              │ How 9-Node Cluster Helps            │
  ├──────────────────────────┼─────────────────────────────────────┤
  │ Execute trades < 50ms    │ Local nodes = low latency           │
  │ Never lose a trade       │ ACID + 9-node replication           │
  │ Show real-time portfolio │ REGIONAL BY ROW = fast local reads  │
  │ Market open 24/7 (crypto)│ 3 regions = always available        │
  │ SEC/SEBI compliance      │ Data stays in user's country        │
  │ Handle market open spike │ 9 nodes absorb load across regions  │
  └──────────────────────────┴─────────────────────────────────────┘
```

### Database Schema (Your Interest: Options Selling & Buying!)

```sql
CREATE DATABASE trading;
USE trading;
ALTER DATABASE trading SET PRIMARY REGION "us-east-1";
ALTER DATABASE trading ADD REGION "eu-west-3";
ALTER DATABASE trading ADD REGION "ap-south-1";
ALTER DATABASE trading SURVIVE REGION FAILURE;

-- Trading accounts with balances
CREATE TABLE trading_accounts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_name STRING NOT NULL,
    email STRING UNIQUE NOT NULL,
    account_type STRING DEFAULT 'cash',
    -- 'cash', 'margin', 'options_approved'
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    buying_power DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    margin_used DECIMAL(15,2) DEFAULT 0.00,
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Stock holdings / portfolio
CREATE TABLE holdings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL,
    symbol STRING NOT NULL,
    quantity DECIMAL(15,6) NOT NULL,
    avg_buy_price DECIMAL(15,4) NOT NULL,
    current_value DECIMAL(15,2),
    region crdb_internal_region NOT NULL,
    UNIQUE (account_id, symbol, region)
) LOCALITY REGIONAL BY ROW AS region;

-- Options contracts
CREATE TABLE options_positions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL,
    symbol STRING NOT NULL,
    option_type STRING NOT NULL,     -- 'CALL' or 'PUT'
    action STRING NOT NULL,          -- 'BUY' or 'SELL'
    strike_price DECIMAL(10,2) NOT NULL,
    expiry_date DATE NOT NULL,
    contracts INT NOT NULL,          -- each contract = 100 shares
    premium_per_contract DECIMAL(10,4) NOT NULL,
    total_premium DECIMAL(15,2) NOT NULL,
    status STRING DEFAULT 'open',
    -- 'open', 'exercised', 'expired', 'closed'
    region crdb_internal_region NOT NULL,
    opened_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;

-- Trade orders (buy/sell stock or options)
CREATE TABLE orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    account_id UUID NOT NULL,
    symbol STRING NOT NULL,
    order_type STRING NOT NULL,
    -- 'market', 'limit', 'stop_loss', 'option_buy', 'option_sell'
    side STRING NOT NULL,            -- 'buy' or 'sell'
    quantity DECIMAL(15,6) NOT NULL,
    price DECIMAL(15,4),             -- NULL for market orders
    filled_price DECIMAL(15,4),
    status STRING DEFAULT 'pending',
    -- 'pending', 'filled', 'partially_filled', 'cancelled'
    region crdb_internal_region NOT NULL,
    placed_at TIMESTAMP DEFAULT now(),
    filled_at TIMESTAMP
) LOCALITY REGIONAL BY ROW AS region;

-- Market data — read from everywhere (GLOBAL)
CREATE TABLE market_data (
    symbol STRING NOT NULL,
    exchange STRING NOT NULL,
    last_price DECIMAL(15,4) NOT NULL,
    day_high DECIMAL(15,4),
    day_low DECIMAL(15,4),
    volume BIGINT,
    updated_at TIMESTAMP DEFAULT now(),
    PRIMARY KEY (symbol, exchange)
) LOCALITY GLOBAL;

-- EXAMPLE: Sell a PUT option (options selling strategy)
BEGIN;
-- Create the options position
INSERT INTO options_positions
    (account_id, symbol, option_type, action, strike_price,
     expiry_date, contracts, premium_per_contract, total_premium, region)
VALUES
    ('your-account-uuid', 'AAPL', 'PUT', 'SELL', 180.00,
     '2026-03-20', 5, 3.50, 1750.00, 'ap-south-1');

-- Credit the premium to your account
UPDATE trading_accounts
    SET balance = balance + 1750.00,
        buying_power = buying_power - (180.00 * 500)  -- margin for 5 contracts
    WHERE id = 'your-account-uuid' AND region = 'ap-south-1';

-- Record the order
INSERT INTO orders
    (account_id, symbol, order_type, side, quantity, price, status, region, filled_at)
VALUES
    ('your-account-uuid', 'AAPL 180P 03/20', 'option_sell', 'sell',
     5, 3.50, 'filled', 'ap-south-1', now());
COMMIT;

-- EXAMPLE: View your options portfolio
SELECT
    symbol, option_type, action,
    strike_price, expiry_date,
    contracts, premium_per_contract,
    total_premium, status
FROM options_positions
WHERE account_id = 'your-account-uuid'
  AND region = 'ap-south-1'
  AND status = 'open'
ORDER BY expiry_date;
```

---

## Application 9: 🌐 Global SaaS Platform (CRM / ERP)

### The Business

A SaaS product like **Salesforce, Zoho, or Freshworks** used by businesses worldwide to manage customers, sales pipelines, and invoicing.

### Why 9 Nodes?

| Need | Solution |
|---|---|
| Enterprise customers demand 99.99%+ uptime | 3-region cluster = survive full region failure |
| EU companies need GDPR compliance | Data stays in Paris nodes |
| Multi-tenant with millions of records | CockroachDB auto-shards data |
| Global teams collaborating | Low latency for each team's region |
| Audit trails required | ACID guarantees no lost records |

### Database Schema

```sql
-- Tenants — SaaS companies using the platform
CREATE TABLE tenants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    company_name STRING NOT NULL,
    plan STRING DEFAULT 'starter',
    primary_region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS primary_region;

-- CRM contacts — stays in tenant's region
CREATE TABLE contacts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tenant_id UUID NOT NULL,
    name STRING NOT NULL,
    email STRING,
    phone STRING,
    company STRING,
    deal_value DECIMAL(15,2),
    stage STRING DEFAULT 'lead',
    -- 'lead', 'qualified', 'proposal', 'negotiation', 'closed_won', 'closed_lost'
    notes STRING,
    region crdb_internal_region NOT NULL,
    created_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;
```

---

## Application 10: ✈️ Global Travel Booking Platform

### The Business

A platform like **Booking.com, MakeMyTrip, or Expedia** handling hotel/flight bookings across the world.

### Why 9 Nodes?

```
  BOOKING PLATFORM DATA FLOW:

  French Tourist            American Tourist         Indian Tourist
  searches hotels           books a flight           cancels hotel
  in Mumbai                 to Paris                 in New York
       │                         │                        │
       ▼                         ▼                        ▼
  Paris Node reads          US-East Node             Mumbai Node
  Mumbai hotel data         writes booking           writes cancellation
  (GLOBAL table = fast!)    (REGIONAL = local!)      (REGIONAL = local!)
```

### Database Schema

```sql
-- Hotels / Flights — available globally (GLOBAL)
CREATE TABLE listings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    type STRING NOT NULL,  -- 'hotel', 'flight', 'package'
    name STRING NOT NULL,
    city STRING NOT NULL,
    country STRING NOT NULL,
    price_per_night DECIMAL(10,2),
    rating DECIMAL(3,2),
    amenities STRING[],
    availability JSONB,
    images STRING[]
) LOCALITY GLOBAL;

-- Bookings — stays in the booker's region
CREATE TABLE bookings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    listing_id UUID NOT NULL,
    check_in DATE NOT NULL,
    check_out DATE NOT NULL,
    guests INT NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    status STRING DEFAULT 'confirmed',
    region crdb_internal_region NOT NULL,
    booked_at TIMESTAMP DEFAULT now()
) LOCALITY REGIONAL BY ROW AS region;
```

### Real Company: Booking.com uses CockroachDB for global operations.

---

## Summary: Which Table Locality to Use?

```
  DECISION CHART FOR TABLE LOCALITY:
  
  ┌─────────────────────────────────────────────────────────┐
  │                                                         │
  │   Is the data READ by everyone but RARELY written?      │
  │   (product catalog, config, exchange rates, rules)      │
  │                                                         │
  │   YES → Use GLOBAL table                                │
  │         (instant reads everywhere, writes go through     │
  │          primary region)                                 │
  │                                                         │
  ├─────────────────────────────────────────────────────────┤
  │                                                         │
  │   Does each ROW belong to a specific region?            │
  │   (user data, orders, transactions, bets, rides)        │
  │                                                         │
  │   YES → Use REGIONAL BY ROW                             │
  │         (each row stored in its region, fast local      │
  │          reads & writes)                                │
  │                                                         │
  ├─────────────────────────────────────────────────────────┤
  │                                                         │
  │   Is the ENTIRE TABLE accessed from one region?         │
  │   (region-specific reports, local analytics)            │
  │                                                         │
  │   YES → Use REGIONAL BY TABLE                           │
  │         (entire table optimized for one region)         │
  │                                                         │
  └─────────────────────────────────────────────────────────┘
```

---

## All 10 Applications at a Glance

| # | Application | Industry | Why Multi-Region? | Key Tables |
|---|---|---|---|---|
| 1 | **Digital Banking** | Fintech | Zero downtime + GDPR + RBI compliance | accounts, transactions, exchange_rates |
| 2 | **E-Commerce** | Retail | Black Friday scaling + data residency | products (GLOBAL), orders, inventory |
| 3 | **Payment Gateway** | Fintech | <100ms processing + PCI compliance | payment_transactions, settlements |
| 4 | **Gaming/Betting** | Gaming | Spike handling + gambling law compliance | player_wallets, bets, game_rules |
| 5 | **Ride-Sharing** | Transport | Real-time matching + local data | drivers, rides, service_configs |
| 6 | **Video Streaming** | Media | Global catalog + local watch history | content (GLOBAL), watch_history |
| 7 | **Telemedicine** | Healthcare | HIPAA/GDPR/DPDPA patient data rules | patients, appointments, doctors |
| 8 | **Stock Trading** | Finance | Low latency trades + SEC/SEBI compliance | holdings, options_positions, orders |
| 9 | **SaaS CRM/ERP** | Software | Enterprise uptime SLA + multi-tenant | tenants, contacts |
| 10 | **Travel Booking** | Travel | Global catalog + local booking data | listings (GLOBAL), bookings |

---

## Companies Already Using Multi-Region CockroachDB

| Company | Industry | Use Case |
|---|---|---|
| **FanDuel** | Gaming/Betting | Financial ledger across 28 US states, 13M+ players |
| **DoorDash** | Food Delivery | Order management across US regions |
| **Booking.com** | Travel | Global hotel booking platform |
| **Santander** | Banking | Global banking operations |
| **SumUp** | Fintech | Payment processing for 4M+ merchants in 35 markets |
| **Riskified** | E-Commerce | Fraud detection (83% lower latency after migration) |
| **Hard Rock Digital** | Gaming | Sports betting and interactive gaming |
| **Shopmonkey** | SaaS | Geo-distributed auto-repair management |
| **CoreWeave** | Cloud/AI | Trillions of objects with strong consistency |

---

*Multi-Region CockroachDB Applications Guide · Real-World Examples with Schemas*
