-- OpenAlgo Trading Application Database Schema for CockroachDB
-- This schema supports algorithmic trading operations with high performance and consistency

-- Use the openalgo database
\c openalgo;

-- ============================================================================
-- ACCOUNTS & BROKERS
-- ============================================================================

-- Broker connections (Zerodha, Upstox, etc.)
CREATE TABLE IF NOT EXISTS brokers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name STRING NOT NULL,
    broker_type STRING NOT NULL, -- 'zerodha', 'upstox', 'finvasia', etc.
    api_key STRING,
    api_secret STRING,
    access_token STRING,
    refresh_token STRING,
    token_expiry TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    UNIQUE INDEX idx_broker_name (name)
);

-- User accounts
CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    broker_id UUID NOT NULL REFERENCES brokers(id),
    account_id STRING NOT NULL,
    account_name STRING,
    balance DECIMAL(15,2) DEFAULT 0,
    margin_available DECIMAL(15,2) DEFAULT 0,
    margin_used DECIMAL(15,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    UNIQUE INDEX idx_account_broker (broker_id, account_id)
);

-- ============================================================================
-- INSTRUMENTS & MARKET DATA
-- ============================================================================

-- Trading instruments (stocks, futures, options)
CREATE TABLE IF NOT EXISTS instruments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol STRING NOT NULL,
    exchange STRING NOT NULL, -- 'NSE', 'BSE', 'MCX', etc.
    instrument_type STRING NOT NULL, -- 'EQ', 'FUT', 'CE', 'PE'
    trading_symbol STRING NOT NULL,
    name STRING,
    expiry DATE,
    strike DECIMAL(10,2),
    lot_size INT DEFAULT 1,
    tick_size DECIMAL(10,4),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    UNIQUE INDEX idx_trading_symbol (trading_symbol, exchange),
    INDEX idx_symbol_exchange (symbol, exchange),
    INDEX idx_expiry (expiry) WHERE expiry IS NOT NULL
);

-- Real-time market data (tick data)
CREATE TABLE IF NOT EXISTS market_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    timestamp TIMESTAMP NOT NULL DEFAULT now(),
    last_price DECIMAL(15,4),
    bid_price DECIMAL(15,4),
    ask_price DECIMAL(15,4),
    bid_qty INT,
    ask_qty INT,
    volume BIGINT,
    open_price DECIMAL(15,4),
    high_price DECIMAL(15,4),
    low_price DECIMAL(15,4),
    close_price DECIMAL(15,4),
    INDEX idx_market_data_instrument_time (instrument_id, timestamp DESC)
) WITH (ttl_expiration_expression = 'timestamp', ttl_expire_after = '7 days');

-- OHLC candles (1min, 5min, 15min, 1hour, 1day)
CREATE TABLE IF NOT EXISTS candles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    timeframe STRING NOT NULL, -- '1min', '5min', '15min', '1hour', '1day'
    timestamp TIMESTAMP NOT NULL,
    open DECIMAL(15,4) NOT NULL,
    high DECIMAL(15,4) NOT NULL,
    low DECIMAL(15,4) NOT NULL,
    close DECIMAL(15,4) NOT NULL,
    volume BIGINT DEFAULT 0,
    UNIQUE INDEX idx_candle_unique (instrument_id, timeframe, timestamp),
    INDEX idx_candle_time (instrument_id, timeframe, timestamp DESC)
);

-- ============================================================================
-- STRATEGIES
-- ============================================================================

-- Trading strategies
CREATE TABLE IF NOT EXISTS strategies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name STRING NOT NULL UNIQUE,
    description STRING,
    strategy_type STRING NOT NULL, -- 'momentum', 'mean_reversion', 'arbitrage', etc.
    parameters JSONB, -- Strategy-specific parameters
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now()
);

-- Strategy execution state
CREATE TABLE IF NOT EXISTS strategy_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES strategies(id),
    account_id UUID NOT NULL REFERENCES accounts(id),
    state JSONB, -- Current state variables
    last_executed TIMESTAMP,
    execution_count BIGINT DEFAULT 0,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    UNIQUE INDEX idx_strategy_account (strategy_id, account_id)
);

-- ============================================================================
-- ORDERS & TRADES
-- ============================================================================

-- Orders
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id STRING, -- Broker's order ID
    account_id UUID NOT NULL REFERENCES accounts(id),
    strategy_id UUID REFERENCES strategies(id),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    
    -- Order details
    order_type STRING NOT NULL, -- 'MARKET', 'LIMIT', 'SL', 'SL-M'
    transaction_type STRING NOT NULL, -- 'BUY', 'SELL'
    product_type STRING NOT NULL, -- 'INTRADAY', 'DELIVERY', 'MARGIN'
    quantity INT NOT NULL,
    price DECIMAL(15,4),
    trigger_price DECIMAL(15,4),
    disclosed_quantity INT DEFAULT 0,
    
    -- Order state
    status STRING NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'OPEN', 'COMPLETE', 'CANCELLED', 'REJECTED'
    filled_quantity INT DEFAULT 0,
    average_price DECIMAL(15,4),
    
    -- Timestamps
    placed_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    executed_at TIMESTAMP,
    
    -- Metadata
    error_message STRING,
    parent_order_id UUID REFERENCES orders(id), -- For bracket/cover orders
    
    INDEX idx_orders_account_status (account_id, status),
    INDEX idx_orders_strategy (strategy_id),
    INDEX idx_orders_placed (placed_at DESC),
    INDEX idx_orders_broker_id (order_id) WHERE order_id IS NOT NULL
);

-- Trades (fills)
CREATE TABLE IF NOT EXISTS trades (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trade_id STRING, -- Broker's trade ID
    order_id UUID NOT NULL REFERENCES orders(id),
    account_id UUID NOT NULL REFERENCES accounts(id),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    
    -- Trade details
    transaction_type STRING NOT NULL, -- 'BUY', 'SELL'
    quantity INT NOT NULL,
    price DECIMAL(15,4) NOT NULL,
    
    -- Charges
    brokerage DECIMAL(10,2) DEFAULT 0,
    exchange_charges DECIMAL(10,2) DEFAULT 0,
    gst DECIMAL(10,2) DEFAULT 0,
    stt DECIMAL(10,2) DEFAULT 0,
    stamp_duty DECIMAL(10,2) DEFAULT 0,
    total_charges DECIMAL(10,2) DEFAULT 0,
    
    -- Net amount
    net_amount DECIMAL(15,2) NOT NULL,
    
    -- Timestamp
    executed_at TIMESTAMP DEFAULT now(),
    
    INDEX idx_trades_order (order_id),
    INDEX idx_trades_account (account_id, executed_at DESC),
    INDEX idx_trades_instrument (instrument_id, executed_at DESC),
    UNIQUE INDEX idx_trade_broker_id (trade_id) WHERE trade_id IS NOT NULL
);

-- ============================================================================
-- POSITIONS & PORTFOLIO
-- ============================================================================

-- Current positions
CREATE TABLE IF NOT EXISTS positions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    product_type STRING NOT NULL, -- 'INTRADAY', 'DELIVERY', 'MARGIN'
    
    -- Position details
    quantity INT NOT NULL DEFAULT 0,
    average_price DECIMAL(15,4) NOT NULL,
    last_price DECIMAL(15,4),
    
    -- P&L
    realized_pnl DECIMAL(15,2) DEFAULT 0,
    unrealized_pnl DECIMAL(15,2) DEFAULT 0,
    total_pnl DECIMAL(15,2) DEFAULT 0,
    
    -- Timestamps
    opened_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    closed_at TIMESTAMP,
    
    UNIQUE INDEX idx_position_unique (account_id, instrument_id, product_type),
    INDEX idx_positions_account (account_id) WHERE quantity != 0
);

-- Historical positions (closed positions)
CREATE TABLE IF NOT EXISTS position_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    strategy_id UUID REFERENCES strategies(id),
    
    -- Position details
    entry_price DECIMAL(15,4) NOT NULL,
    exit_price DECIMAL(15,4) NOT NULL,
    quantity INT NOT NULL,
    
    -- P&L
    realized_pnl DECIMAL(15,2) NOT NULL,
    pnl_percentage DECIMAL(10,4) NOT NULL,
    
    -- Charges
    total_charges DECIMAL(10,2) DEFAULT 0,
    
    -- Timestamps
    opened_at TIMESTAMP NOT NULL,
    closed_at TIMESTAMP NOT NULL,
    holding_period INTERVAL AS (closed_at - opened_at) STORED,
    
    INDEX idx_position_history_account (account_id, closed_at DESC),
    INDEX idx_position_history_strategy (strategy_id, closed_at DESC),
    INDEX idx_position_history_pnl (realized_pnl DESC)
);

-- ============================================================================
-- SIGNALS & ALERTS
-- ============================================================================

-- Trading signals generated by strategies
CREATE TABLE IF NOT EXISTS signals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES strategies(id),
    instrument_id UUID NOT NULL REFERENCES instruments(id),
    
    -- Signal details
    signal_type STRING NOT NULL, -- 'BUY', 'SELL', 'HOLD', 'EXIT'
    confidence DECIMAL(5,4), -- 0.0 to 1.0
    price DECIMAL(15,4),
    target_price DECIMAL(15,4),
    stop_loss DECIMAL(15,4),
    
    -- Metadata
    metadata JSONB,
    
    -- State
    is_executed BOOLEAN DEFAULT false,
    generated_at TIMESTAMP DEFAULT now(),
    executed_at TIMESTAMP,
    
    INDEX idx_signals_strategy (strategy_id, generated_at DESC),
    INDEX idx_signals_pending (is_executed, generated_at) WHERE is_executed = false
);

-- Alerts and notifications
CREATE TABLE IF NOT EXISTS alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_type STRING NOT NULL, -- 'PRICE', 'POSITION', 'RISK', 'SYSTEM'
    severity STRING NOT NULL, -- 'INFO', 'WARNING', 'CRITICAL'
    title STRING NOT NULL,
    message STRING NOT NULL,
    metadata JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT now(),
    INDEX idx_alerts_unread (created_at DESC) WHERE is_read = false
);

-- ============================================================================
-- RISK MANAGEMENT
-- ============================================================================

-- Risk limits per account/strategy
CREATE TABLE IF NOT EXISTS risk_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID REFERENCES accounts(id),
    strategy_id UUID REFERENCES strategies(id),
    
    -- Position limits
    max_positions INT,
    max_position_size DECIMAL(15,2),
    max_position_value DECIMAL(15,2),
    
    -- Loss limits
    max_daily_loss DECIMAL(15,2),
    max_loss_per_trade DECIMAL(15,2),
    max_drawdown DECIMAL(5,4), -- Percentage
    
    -- Exposure limits
    max_portfolio_exposure DECIMAL(15,2),
    max_sector_exposure DECIMAL(15,2),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    
    UNIQUE INDEX idx_risk_account_strategy (account_id, strategy_id)
);

-- Daily risk tracking
CREATE TABLE IF NOT EXISTS daily_risk_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id),
    date DATE NOT NULL,
    
    -- Daily metrics
    daily_pnl DECIMAL(15,2) DEFAULT 0,
    max_drawdown DECIMAL(15,2) DEFAULT 0,
    trades_count INT DEFAULT 0,
    winning_trades INT DEFAULT 0,
    losing_trades INT DEFAULT 0,
    
    -- Exposure
    max_exposure DECIMAL(15,2) DEFAULT 0,
    avg_exposure DECIMAL(15,2) DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT now(),
    updated_at TIMESTAMP DEFAULT now(),
    
    UNIQUE INDEX idx_risk_metrics_account_date (account_id, date)
);

-- ============================================================================
-- AUDIT & LOGGING
-- ============================================================================

-- Audit log for all critical operations
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    action STRING NOT NULL,
    entity_type STRING NOT NULL, -- 'order', 'strategy', 'position', etc.
    entity_id UUID,
    old_value JSONB,
    new_value JSONB,
    ip_address STRING,
    user_agent STRING,
    created_at TIMESTAMP DEFAULT now(),
    INDEX idx_audit_created (created_at DESC),
    INDEX idx_audit_entity (entity_type, entity_id)
) WITH (ttl_expiration_expression = 'created_at', ttl_expire_after = '90 days');

-- System events log
CREATE TABLE IF NOT EXISTS system_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type STRING NOT NULL, -- 'ERROR', 'WARNING', 'INFO', 'PERFORMANCE'
    component STRING NOT NULL, -- 'strategy_engine', 'order_executor', 'market_data', etc.
    message STRING NOT NULL,
    details JSONB,
    created_at TIMESTAMP DEFAULT now(),
    INDEX idx_events_created (created_at DESC),
    INDEX idx_events_type (event_type, created_at DESC)
) WITH (ttl_expiration_expression = 'created_at', ttl_expire_after = '30 days');

-- ============================================================================
-- PERFORMANCE TRACKING
-- ============================================================================

-- Strategy performance metrics
CREATE TABLE IF NOT EXISTS strategy_performance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    strategy_id UUID NOT NULL REFERENCES strategies(id),
    period STRING NOT NULL, -- 'daily', 'weekly', 'monthly', 'yearly'
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    
    -- Performance metrics
    total_trades INT DEFAULT 0,
    winning_trades INT DEFAULT 0,
    losing_trades INT DEFAULT 0,
    win_rate DECIMAL(5,4) DEFAULT 0,
    
    -- P&L metrics
    total_pnl DECIMAL(15,2) DEFAULT 0,
    average_win DECIMAL(15,2) DEFAULT 0,
    average_loss DECIMAL(15,2) DEFAULT 0,
    largest_win DECIMAL(15,2) DEFAULT 0,
    largest_loss DECIMAL(15,2) DEFAULT 0,
    profit_factor DECIMAL(10,4) DEFAULT 0, -- Gross profit / Gross loss
    
    -- Risk metrics
    max_drawdown DECIMAL(15,2) DEFAULT 0,
    sharpe_ratio DECIMAL(10,4),
    sortino_ratio DECIMAL(10,4),
    
    created_at TIMESTAMP DEFAULT now(),
    
    UNIQUE INDEX idx_strategy_perf_period (strategy_id, period, period_start)
);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Active positions with current P&L
CREATE VIEW v_active_positions AS
SELECT 
    p.id,
    p.account_id,
    a.account_name,
    i.trading_symbol,
    i.exchange,
    p.quantity,
    p.average_price,
    p.last_price,
    p.unrealized_pnl,
    p.realized_pnl,
    p.total_pnl,
    (p.unrealized_pnl / (p.average_price * p.quantity) * 100) as pnl_percentage,
    p.opened_at
FROM positions p
JOIN accounts a ON p.account_id = a.id
JOIN instruments i ON p.instrument_id = i.id
WHERE p.quantity != 0
ORDER BY p.total_pnl DESC;

-- Today's orders summary
CREATE VIEW v_todays_orders AS
SELECT 
    o.id,
    o.order_id,
    a.account_name,
    i.trading_symbol,
    o.transaction_type,
    o.order_type,
    o.quantity,
    o.filled_quantity,
    o.price,
    o.status,
    o.placed_at,
    s.name as strategy_name
FROM orders o
JOIN accounts a ON o.account_id = a.id
JOIN instruments i ON o.instrument_id = i.id
LEFT JOIN strategies s ON o.strategy_id = s.id
WHERE DATE(o.placed_at) = CURRENT_DATE
ORDER BY o.placed_at DESC;

-- Daily P&L summary
CREATE VIEW v_daily_pnl AS
SELECT 
    account_id,
    DATE(executed_at) as trade_date,
    SUM(CASE WHEN transaction_type = 'BUY' THEN -net_amount ELSE net_amount END) as daily_pnl,
    COUNT(*) as trades_count
FROM trades
GROUP BY account_id, DATE(executed_at)
ORDER BY trade_date DESC;

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Additional composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_orders_account_placed ON orders (account_id, placed_at DESC);
CREATE INDEX IF NOT EXISTS idx_trades_account_executed ON trades (account_id, executed_at DESC);
CREATE INDEX IF NOT EXISTS idx_market_data_composite ON market_data (instrument_id, timestamp DESC);

-- ============================================================================
-- GRANTS
-- ============================================================================

-- Grant permissions to openalgo user
GRANT ALL ON DATABASE openalgo TO openalgo;
GRANT ALL ON ALL TABLES IN SCHEMA public TO openalgo;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO openalgo;

-- ============================================================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================================================

-- Insert sample broker
INSERT INTO brokers (name, broker_type, is_active) 
VALUES ('Demo Broker', 'demo', true)
ON CONFLICT DO NOTHING;

-- Insert sample instruments
INSERT INTO instruments (symbol, exchange, instrument_type, trading_symbol, name, lot_size) 
VALUES 
    ('RELIANCE', 'NSE', 'EQ', 'RELIANCE-EQ', 'Reliance Industries Ltd', 1),
    ('TCS', 'NSE', 'EQ', 'TCS-EQ', 'Tata Consultancy Services Ltd', 1),
    ('INFY', 'NSE', 'EQ', 'INFY-EQ', 'Infosys Ltd', 1),
    ('HDFCBANK', 'NSE', 'EQ', 'HDFCBANK-EQ', 'HDFC Bank Ltd', 1),
    ('NIFTY', 'NSE', 'FUT', 'NIFTY24FEBFUT', 'Nifty 50 Feb Future', 50)
ON CONFLICT DO NOTHING;

COMMIT;
