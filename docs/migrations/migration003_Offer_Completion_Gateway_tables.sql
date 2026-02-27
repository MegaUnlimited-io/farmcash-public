-- =====================================================
-- FarmCash OCG Migration - TRANSACTION WRAPPED
-- =====================================================
-- This version wraps everything in BEGIN/COMMIT
-- Result: Either ALL changes succeed, or NONE do
-- No partial state possible
-- =====================================================

BEGIN;

-- =====================================================
-- FarmCash OCG (Offer Completion Gateway) Migration
-- =====================================================
-- Purpose: Add database tables and functions for postback handling
-- Created: 2026-01-13
-- Dependencies: Existing public.users table with seeds_balance

-- =====================================================
-- Table 1: postback_log
-- Purpose: Complete audit trail of all postbacks
-- =====================================================

CREATE TABLE IF NOT EXISTS postback_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Partner identification
  partner VARCHAR(50) NOT NULL,
  action_id VARCHAR(255) NOT NULL,
  
  -- User and offer information
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  offer_id VARCHAR(100),
  offer_name TEXT,
  
  -- Transaction details
  currency_amount INTEGER NOT NULL,  -- Seeds credited (negative for reversals)
  status VARCHAR(20) NOT NULL CHECK (status IN ('completed', 'reversed')),
  commission DECIMAL(10,2),  -- What partner paid us
  
  -- Processing metadata
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  response_code INTEGER,  -- HTTP response code we sent (200, 400, 409, etc.)
  response_body TEXT,     -- Response message ('SUCCESS', 'DUPLICATE', etc.)
  
  -- Full request data for debugging
  raw_params JSONB,
  
  -- Prevent duplicate logging of same conversion
  UNIQUE(partner, action_id)
);

-- Indexes for fast queries
CREATE INDEX idx_postback_user ON postback_log(user_id, processed_at);
CREATE INDEX idx_postback_partner ON postback_log(partner, processed_at);
CREATE INDEX idx_postback_action ON postback_log(action_id);
CREATE INDEX idx_postback_status ON postback_log(status, processed_at);

-- Comment for documentation
COMMENT ON TABLE postback_log IS 'Complete audit trail of all partner postbacks (success and failure)';
COMMENT ON COLUMN postback_log.currency_amount IS 'Seeds credited - negative values indicate reversals';
COMMENT ON COLUMN postback_log.raw_params IS 'Full JSONB of request parameters for debugging and reconciliation';

-- =====================================================
-- Table 2: postback_deduplication
-- Purpose: Fast duplicate detection
-- =====================================================

CREATE TABLE IF NOT EXISTS postback_deduplication (
  partner VARCHAR(50) NOT NULL,
  action_id VARCHAR(255) NOT NULL,
  processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  PRIMARY KEY (partner, action_id)
);

-- Index for cleanup queries (remove old entries)
CREATE INDEX idx_dedup_cleanup ON postback_deduplication(processed_at);

COMMENT ON TABLE postback_deduplication IS 'Lightweight duplicate prevention - check before processing';

-- =====================================================
-- Table 3: seed_transactions
-- Purpose: Complete transaction ledger for seeds
-- =====================================================

CREATE TABLE IF NOT EXISTS seed_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Who and when
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Transaction details
  amount INTEGER NOT NULL,  -- Positive = credit, Negative = debit
  source VARCHAR(50) NOT NULL,  -- 'POSTBACK', 'BONUS', 'REVERSAL', 'PLANT_CROP', 'ADMIN_ADJUSTMENT'
  reference VARCHAR(255),  -- Foreign reference (action_id, offer_id, crop_id, etc.)
  
  -- Balance tracking
  balance_after INTEGER NOT NULL,  -- User's seed balance after this transaction
  
  -- Additional context
  metadata JSONB  -- Optional extra data (offer name, reason, etc.)
);

-- Indexes for user transaction history
CREATE INDEX idx_seed_tx_user ON seed_transactions(user_id, created_at DESC);
CREATE INDEX idx_seed_tx_reference ON seed_transactions(reference);
CREATE INDEX idx_seed_tx_source ON seed_transactions(source, created_at);

COMMENT ON TABLE seed_transactions IS 'Complete ledger of all seed movements - credits, debits, reversals';
COMMENT ON COLUMN seed_transactions.amount IS 'Positive = credit, Negative = debit';
COMMENT ON COLUMN seed_transactions.source IS 'Transaction type: POSTBACK, BONUS, REVERSAL, PLANT_CROP, ADMIN_ADJUSTMENT';
COMMENT ON COLUMN seed_transactions.balance_after IS 'Snapshot of user seed balance after transaction - enables audit and reconciliation';

-- =====================================================
-- Table 4: fraud_events
-- Purpose: Security and fraud tracking
-- =====================================================

CREATE TABLE IF NOT EXISTS fraud_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Event identification
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,  -- Allow NULL for system-wide events
  event_type VARCHAR(50) NOT NULL,
  severity VARCHAR(20) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
  
  -- Event details
  details JSONB NOT NULL,  -- Flexible structure for different event types
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Investigation tracking
  reviewed BOOLEAN DEFAULT FALSE,
  reviewed_at TIMESTAMP WITH TIME ZONE,
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  resolution TEXT
);

-- Indexes for fraud monitoring
CREATE INDEX idx_fraud_user ON fraud_events(user_id, created_at DESC);
CREATE INDEX idx_fraud_type ON fraud_events(event_type, severity, created_at DESC);
CREATE INDEX idx_fraud_unreviewed ON fraud_events(reviewed, severity, created_at) WHERE reviewed = FALSE;

COMMENT ON TABLE fraud_events IS 'Security and fraud event logging for investigation and alerting';
COMMENT ON COLUMN fraud_events.event_type IS 'HIGH_VELOCITY, DUPLICATE_OFFER, GEO_MISMATCH, NEGATIVE_BALANCE, etc.';
COMMENT ON COLUMN fraud_events.details IS 'JSONB context - structure varies by event_type';

-- =====================================================
-- Function: process_postback
-- Purpose: Atomic transaction for postback processing
-- =====================================================

CREATE OR REPLACE FUNCTION process_postback(
  p_partner VARCHAR(50),
  p_action_id VARCHAR(255),
  p_user_id UUID,
  p_currency INTEGER,
  p_offer_id VARCHAR(100),
  p_offer_name TEXT,
  p_status VARCHAR(20),
  p_commission NUMERIC DEFAULT NULL,
  p_raw_params JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_new_balance INTEGER;
  v_old_balance INTEGER;
  v_duplicate BOOLEAN;
BEGIN
  -- ============================================
  -- Step 1: Check for duplicate
  -- ============================================
  SELECT EXISTS (
    SELECT 1 FROM postback_deduplication 
    WHERE partner = p_partner AND action_id = p_action_id
  ) INTO v_duplicate;
  
  IF v_duplicate THEN
    -- Log the duplicate attempt
    INSERT INTO postback_log (
      partner, action_id, user_id, offer_id, offer_name,
      currency_amount, status, commission, response_code, 
      response_body, raw_params
    ) VALUES (
      p_partner, p_action_id, p_user_id, p_offer_id, p_offer_name,
      p_currency, p_status, p_commission, 409, 
      'DUPLICATE', p_raw_params
    );
    
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'DUPLICATE',
      'action_id', p_action_id
    );
  END IF;
  
  -- ============================================
  -- Step 2: Record deduplication entry
  -- ============================================
  INSERT INTO postback_deduplication (partner, action_id)
  VALUES (p_partner, p_action_id);
  
  -- ============================================
  -- Step 3: Get current balance and update
  -- ============================================
  SELECT seeds_balance INTO v_old_balance
  FROM public.users
  WHERE id = p_user_id;
  
  -- If user not found, raise exception (will rollback transaction)
  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;
  
  -- Update user's seed balance
  UPDATE public.users
  SET seeds_balance = seeds_balance + p_currency
  WHERE id = p_user_id
  RETURNING seeds_balance INTO v_new_balance;
  
  -- ============================================
  -- Step 4: Log seed transaction
  -- ============================================
  INSERT INTO seed_transactions (
    user_id, amount, source, reference, balance_after, metadata
  ) VALUES (
    p_user_id, 
    p_currency, 
    CASE WHEN p_status = 'reversed' THEN 'REVERSAL' ELSE 'POSTBACK' END,
    p_action_id,
    v_new_balance,
    jsonb_build_object(
      'partner', p_partner,
      'offer_id', p_offer_id,
      'offer_name', p_offer_name,
      'commission', p_commission
    )
  );
  
  -- ============================================
  -- Step 5: Log postback
  -- ============================================
  INSERT INTO postback_log (
    partner, action_id, user_id, offer_id, offer_name,
    currency_amount, status, commission, response_code,
    response_body, raw_params
  ) VALUES (
    p_partner, p_action_id, p_user_id, p_offer_id, p_offer_name,
    p_currency, p_status, p_commission, 200,
    'SUCCESS', p_raw_params
  );
  
  -- ============================================
  -- Step 6: Check for fraud indicators
  -- ============================================
  -- Flag negative balance as fraud event
  IF v_new_balance < 0 THEN
    INSERT INTO fraud_events (
      user_id, event_type, severity, details
    ) VALUES (
      p_user_id,
      'NEGATIVE_BALANCE',
      'HIGH',
      jsonb_build_object(
        'balance', v_new_balance,
        'transaction_amount', p_currency,
        'action_id', p_action_id,
        'partner', p_partner
      )
    );
  END IF;
  
  -- ============================================
  -- Step 7: Return success
  -- ============================================
  RETURN jsonb_build_object(
    'success', true,
    'new_balance', v_new_balance,
    'old_balance', v_old_balance,
    'transaction_amount', p_currency,
    'action_id', p_action_id
  );
  
EXCEPTION
  WHEN OTHERS THEN
    -- Any error rolls back entire transaction
    -- Log the error and return failure
    RAISE WARNING 'process_postback error: %', SQLERRM;
    
    RETURN jsonb_build_object(
      'success', false,
      'reason', 'INTERNAL_ERROR',
      'error', SQLERRM
    );
END;
$$;

COMMENT ON FUNCTION process_postback IS 'Atomic postback processing - checks duplicate, credits seeds, logs everything';

-- =====================================================
-- Row Level Security (RLS) Policies
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE postback_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE postback_deduplication ENABLE ROW LEVEL SECURITY;
ALTER TABLE seed_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE fraud_events ENABLE ROW LEVEL SECURITY;

-- postback_log: Users can view their own postbacks
CREATE POLICY "Users can view their own postbacks"
  ON postback_log
  FOR SELECT
  USING (auth.uid() = user_id);

-- postback_log: Service role can do anything (for Edge Function)
CREATE POLICY "Service role can manage postbacks"
  ON postback_log
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- postback_deduplication: Only service role
CREATE POLICY "Service role can manage deduplication"
  ON postback_deduplication
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- seed_transactions: Users can view their own transaction history
CREATE POLICY "Users can view their own transactions"
  ON seed_transactions
  FOR SELECT
  USING (auth.uid() = user_id);

-- seed_transactions: Service role can insert
CREATE POLICY "Service role can insert transactions"
  ON seed_transactions
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- fraud_events: Users cannot view (admin only via direct SQL)
-- Service role can insert/update for automated detection
CREATE POLICY "Service role can manage fraud events"
  ON fraud_events
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- =====================================================
-- Utility Functions
-- =====================================================

-- Function: Get user transaction history
CREATE OR REPLACE FUNCTION get_user_transactions(
  p_user_id UUID,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  amount INTEGER,
  source VARCHAR(50),
  reference VARCHAR(255),
  balance_after INTEGER,
  created_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Verify requesting user matches or is service role
  IF auth.uid() != p_user_id AND auth.role() != 'service_role' THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  
  RETURN QUERY
  SELECT 
    t.id, t.amount, t.source, t.reference, 
    t.balance_after, t.created_at, t.metadata
  FROM seed_transactions t
  WHERE t.user_id = p_user_id
  ORDER BY t.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

COMMENT ON FUNCTION get_user_transactions IS 'Retrieve paginated transaction history for a user';

-- Function: Cleanup old deduplication records (run via cron)
CREATE OR REPLACE FUNCTION cleanup_old_deduplication_records(
  p_days_to_keep INTEGER DEFAULT 90
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  DELETE FROM postback_deduplication
  WHERE processed_at < NOW() - (p_days_to_keep || ' days')::INTERVAL;
  
  GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
  
  RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION cleanup_old_deduplication_records IS 'Delete deduplication records older than N days to keep table size manageable';

-- =====================================================
-- End of Migration
-- =====================================================

-- =====================================================
-- COMMIT TRANSACTION
-- =====================================================
-- If you got here without errors, everything worked!
COMMIT;