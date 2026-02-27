-- ============================================================================
-- MIGRATION006: WAITLIST SIGNUPS & REWARD SYSTEM
-- Created: 2026-02-12 12:00 PM
-- Purpose: Track web waitlist signups with fraud detection and automated rewards
-- ============================================================================

-- ============================================================================
-- 1. CREATE WAITLIST_SIGNUPS TABLE
-- ============================================================================

CREATE TABLE public.waitlist_signups (
  -- Core Identity
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  
  -- Survey Answers
  game_type TEXT,
  rewarded_apps TEXT[],
  devices TEXT[],
  
  -- Fraud Detection (Minimal for Waitlist)
  ip_address TEXT,
  timezone TEXT,
  browser TEXT,
  os TEXT,
  device_type TEXT,
  fingerprint_hash TEXT,
  fraud_status TEXT DEFAULT 'pending' CHECK (
    fraud_status IN ('pending', 'approved', 'suspicious', 'flagged', 'rejected')
  ),
  
  -- Status Tracking
  email_verified BOOLEAN DEFAULT false,
  email_verified_at TIMESTAMPTZ,
  migrated_to_app BOOLEAN DEFAULT false,
  migrated_at TIMESTAMPTZ,
  
  -- Marketing (Reserved for Future)
  referrer TEXT,
  utm_source TEXT,
  utm_medium TEXT,
  utm_campaign TEXT,
  
  -- Constraints
  UNIQUE(user_id),
  UNIQUE(email)
);

-- Comments for documentation
COMMENT ON TABLE public.waitlist_signups IS 'Tracks web waitlist signups with survey answers and fraud detection data';
COMMENT ON COLUMN public.waitlist_signups.fraud_status IS 'pending=new, approved=verified, suspicious=auto-flagged, flagged=admin review, rejected=blocked';
COMMENT ON COLUMN public.waitlist_signups.fingerprint_hash IS 'Simple hash for duplicate detection (ip-timezone-browser-os)';

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================

CREATE INDEX idx_waitlist_user_id ON public.waitlist_signups(user_id);
CREATE INDEX idx_waitlist_email ON public.waitlist_signups(email);
CREATE INDEX idx_waitlist_fingerprint ON public.waitlist_signups(fingerprint_hash);
CREATE INDEX idx_waitlist_ip ON public.waitlist_signups(ip_address);
CREATE INDEX idx_waitlist_created ON public.waitlist_signups(created_at DESC);
CREATE INDEX idx_waitlist_fraud_status ON public.waitlist_signups(fraud_status);
CREATE INDEX idx_waitlist_verified ON public.waitlist_signups(email_verified);

-- ============================================================================
-- 3. ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE public.waitlist_signups ENABLE ROW LEVEL SECURITY;

-- Users can view only their own waitlist data
CREATE POLICY "Users can view own waitlist data"
  ON public.waitlist_signups FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert only their own waitlist data
CREATE POLICY "Users can insert own waitlist data"
  ON public.waitlist_signups FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update only their own waitlist data
CREATE POLICY "Users can update own waitlist data"
  ON public.waitlist_signups FOR UPDATE
  USING (auth.uid() = user_id);

-- ============================================================================
-- 4. HELPER FUNCTION: RECORD SEED TRANSACTION
-- ============================================================================

CREATE OR REPLACE FUNCTION record_seed_transaction(
  p_user_id UUID,
  p_amount INTEGER,
  p_source TEXT,
  p_reference TEXT,
  p_metadata JSONB DEFAULT '{}'
) RETURNS INTEGER AS $$
DECLARE
  v_new_balance INTEGER;
BEGIN
  -- Update user seeds balance
  UPDATE public.users
  SET seeds_balance = seeds_balance + p_amount
  WHERE id = p_user_id
  RETURNING seeds_balance INTO v_new_balance;
  
  -- Record transaction in audit log
  INSERT INTO public.seed_transactions (
    user_id,
    amount,
    source,
    reference,
    balance_after,
    metadata
  ) VALUES (
    p_user_id,
    p_amount,
    p_source,
    p_reference,
    v_new_balance,
    p_metadata
  );
  
  RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION record_seed_transaction IS 'Generic function to record seed transactions with automatic balance updates and audit logging';

-- ============================================================================
-- 5. FUNCTION: AWARD SIGNUP BONUS
-- ============================================================================

CREATE OR REPLACE FUNCTION award_signup_bonus(
  p_user_id UUID
) RETURNS TABLE(
  success BOOLEAN,
  seeds_awarded INTEGER,
  new_balance INTEGER,
  message TEXT
) AS $$
DECLARE
  v_bonus_amount INTEGER;
  v_new_balance INTEGER;
  v_already_awarded BOOLEAN;
BEGIN
  -- Get bonus amount from config (default 100)
  SELECT COALESCE(
    (SELECT config_value::integer FROM app_config WHERE config_key = 'signup_bonus_seeds'),
    100
  ) INTO v_bonus_amount;
  
  -- Check if already awarded (idempotency check)
  SELECT EXISTS(
    SELECT 1 FROM public.seed_transactions
    WHERE user_id = p_user_id 
      AND source = 'signup_bonus'
  ) INTO v_already_awarded;
  
  IF v_already_awarded THEN
    RETURN QUERY SELECT 
      false,
      0,
      (SELECT seeds_balance FROM public.users WHERE id = p_user_id),
      'Signup bonus already claimed'::TEXT;
    RETURN;
  END IF;
  
  -- Award bonus seeds
  v_new_balance := record_seed_transaction(
    p_user_id,
    v_bonus_amount,
    'signup_bonus',
    'waitlist_signup',
    jsonb_build_object(
      'awarded_at', now(),
      'bonus_type', 'signup'
    )
  );
  
  -- Return success
  RETURN QUERY SELECT 
    true,
    v_bonus_amount,
    v_new_balance,
    format('Signup bonus awarded! +%s seeds 🌱', v_bonus_amount)::TEXT;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false,
      0,
      0,
      SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION award_signup_bonus IS 'Awards one-time signup bonus (default 100 seeds) to new waitlist users';

-- ============================================================================
-- 6. FUNCTION: AWARD EMAIL VERIFICATION BONUS
-- ============================================================================

CREATE OR REPLACE FUNCTION award_verification_bonus(
  p_user_id UUID
) RETURNS TABLE(
  success BOOLEAN,
  seeds_awarded INTEGER,
  new_balance INTEGER,
  message TEXT
) AS $$
DECLARE
  v_bonus_amount INTEGER;
  v_new_balance INTEGER;
  v_already_awarded BOOLEAN;
  v_email_verified BOOLEAN;
BEGIN
  -- Get bonus amount from config (default 50)
  SELECT COALESCE(
    (SELECT config_value::integer FROM app_config WHERE config_key = 'email_verification_bonus_seeds'),
    50
  ) INTO v_bonus_amount;
  
  -- Check if email is verified
  SELECT email_verified 
  INTO v_email_verified
  FROM public.waitlist_signups
  WHERE user_id = p_user_id;
  
  IF NOT COALESCE(v_email_verified, false) THEN
    RETURN QUERY SELECT 
      false,
      0,
      (SELECT seeds_balance FROM public.users WHERE id = p_user_id),
      'Email not verified yet'::TEXT;
    RETURN;
  END IF;
  
  -- Check if already awarded (idempotency check)
  SELECT EXISTS(
    SELECT 1 FROM public.seed_transactions
    WHERE user_id = p_user_id 
      AND source = 'email_verification'
  ) INTO v_already_awarded;
  
  IF v_already_awarded THEN
    RETURN QUERY SELECT 
      false,
      0,
      (SELECT seeds_balance FROM public.users WHERE id = p_user_id),
      'Verification bonus already claimed'::TEXT;
    RETURN;
  END IF;
  
  -- Award bonus seeds
  v_new_balance := record_seed_transaction(
    p_user_id,
    v_bonus_amount,
    'email_verification',
    'email_confirmed',
    jsonb_build_object(
      'awarded_at', now(),
      'bonus_type', 'verification'
    )
  );
  
  -- Update fraud status to approved if still pending
  UPDATE public.waitlist_signups
  SET fraud_status = 'approved'
  WHERE user_id = p_user_id 
    AND fraud_status = 'pending';
  
  -- Return success
  RETURN QUERY SELECT 
    true,
    v_bonus_amount,
    v_new_balance,
    format('Email verified! +%s seeds ✉️', v_bonus_amount)::TEXT;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false,
      0,
      0,
      SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION award_verification_bonus IS 'Awards one-time email verification bonus (default 50 seeds) after email confirmation';

-- ============================================================================
-- 7. FUNCTION: AWARD REFERRAL BONUS
-- ============================================================================

CREATE OR REPLACE FUNCTION award_referral_bonus(
  p_referrer_id UUID,
  p_referee_id UUID
) RETURNS TABLE(
  success BOOLEAN,
  seeds_awarded INTEGER,
  new_balance INTEGER,
  referral_number INTEGER,
  message TEXT
) AS $$
DECLARE
  v_referral_count INTEGER;
  v_bonus_amount INTEGER;
  v_new_balance INTEGER;
  v_already_awarded BOOLEAN;
BEGIN
  -- Get current referral count
  SELECT referral_count
  INTO v_referral_count
  FROM public.users
  WHERE id = p_referrer_id;
  
  -- Increment referral count
  UPDATE public.users
  SET referral_count = referral_count + 1
  WHERE id = p_referrer_id
  RETURNING referral_count INTO v_referral_count;
  
  -- Check if already awarded for this referee (prevent double-payment)
  SELECT EXISTS(
    SELECT 1 FROM public.seed_transactions
    WHERE user_id = p_referrer_id 
      AND source = 'referral_reward'
      AND reference = format('referral_%s', v_referral_count)
      AND (metadata->>'referee_id')::uuid = p_referee_id
  ) INTO v_already_awarded;
  
  IF v_already_awarded THEN
    RETURN QUERY SELECT 
      false,
      0,
      (SELECT seeds_balance FROM public.users WHERE id = p_referrer_id),
      v_referral_count,
      'Referral bonus already awarded for this user'::TEXT;
    RETURN;
  END IF;
  
  -- Determine bonus amount based on referral count
  v_bonus_amount := CASE
    WHEN v_referral_count = 1 THEN 200
    WHEN v_referral_count = 2 THEN 100
    WHEN v_referral_count = 3 THEN 50
    ELSE 0  -- Track but don't pay for 4+
  END;
  
  -- Record transaction (even if amount is 0 for audit trail)
  v_new_balance := record_seed_transaction(
    p_referrer_id,
    v_bonus_amount,
    'referral_reward',
    format('referral_%s%s', v_referral_count, CASE WHEN v_bonus_amount = 0 THEN '_unpaid' ELSE '' END),
    jsonb_build_object(
      'awarded_at', now(),
      'referee_id', p_referee_id,
      'referral_number', v_referral_count,
      'bonus_amount', v_bonus_amount
    )
  );
  
  -- Return success with appropriate message
  RETURN QUERY SELECT 
    true,
    v_bonus_amount,
    v_new_balance,
    v_referral_count,
    CASE 
      WHEN v_bonus_amount > 0 THEN format('Referral #%s rewarded! +%s seeds 🎉', v_referral_count, v_bonus_amount)
      ELSE format('Referral #%s tracked (no additional reward) 📊', v_referral_count)
    END::TEXT;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false,
      0,
      0,
      0,
      SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION award_referral_bonus IS 'Awards referral bonuses: 1st=200, 2nd=100, 3rd=50 seeds. Tracks but does not pay for referrals 4+';

-- ============================================================================
-- 8. FUNCTION: PROCESS EMAIL VERIFICATION (ORCHESTRATOR)
-- ============================================================================

CREATE OR REPLACE FUNCTION process_email_verification(
  p_user_id UUID,
  p_referred_by UUID DEFAULT NULL
) RETURNS TABLE(
  success BOOLEAN,
  total_seeds_awarded INTEGER,
  breakdown JSONB,
  message TEXT
) AS $$
DECLARE
  v_signup_result RECORD;
  v_verify_result RECORD;
  v_referral_result RECORD;
  v_total_seeds INTEGER := 0;
  v_breakdown JSONB := '{}';
BEGIN
  -- Mark email as verified in waitlist_signups
  UPDATE public.waitlist_signups
  SET 
    email_verified = true,
    email_verified_at = now()
  WHERE user_id = p_user_id;
  
  -- 1. Award signup bonus (+100 seeds)
  SELECT * INTO v_signup_result
  FROM award_signup_bonus(p_user_id);
  
  IF v_signup_result.success THEN
    v_total_seeds := v_total_seeds + v_signup_result.seeds_awarded;
    v_breakdown := v_breakdown || jsonb_build_object('signup_bonus', v_signup_result.seeds_awarded);
  END IF;
  
  -- 2. Award verification bonus (+50 seeds)
  SELECT * INTO v_verify_result
  FROM award_verification_bonus(p_user_id);
  
  IF v_verify_result.success THEN
    v_total_seeds := v_total_seeds + v_verify_result.seeds_awarded;
    v_breakdown := v_breakdown || jsonb_build_object('verification_bonus', v_verify_result.seeds_awarded);
  END IF;
  
  -- 3. Award referral bonus to referrer if applicable
  IF p_referred_by IS NOT NULL THEN
    SELECT * INTO v_referral_result
    FROM award_referral_bonus(p_referred_by, p_user_id);
    
    IF v_referral_result.success AND v_referral_result.seeds_awarded > 0 THEN
      v_breakdown := v_breakdown || jsonb_build_object(
        'referral_awarded_to_referrer', v_referral_result.seeds_awarded,
        'referrer_id', p_referred_by
      );
    END IF;
  END IF;
  
  -- Return summary
  RETURN QUERY SELECT 
    true,
    v_total_seeds,
    v_breakdown,
    format('Welcome to FarmCash! You received %s seeds 🌱', v_total_seeds)::TEXT;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false,
      0,
      '{}'::JSONB,
      SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION process_email_verification IS 'Orchestrates all email verification rewards: signup bonus, verification bonus, and referral rewards';

-- ============================================================================
-- 9. ADD FRAUD DETECTION PLACEHOLDERS (FOR FUTURE IPQS INTEGRATION)
-- ============================================================================

-- Placeholder function for external fraud check
-- TODO: Integrate with IPQS API when ready
CREATE OR REPLACE FUNCTION check_fraud_signals(
  p_ip_address TEXT,
  p_email TEXT,
  p_fingerprint_hash TEXT
) RETURNS TABLE(
  risk_score INTEGER,
  is_vpn BOOLEAN,
  is_proxy BOOLEAN,
  is_disposable_email BOOLEAN,
  country_code TEXT,
  fraud_status TEXT
) AS $$
BEGIN
  -- PLACEHOLDER: Return safe defaults for now
  -- TODO: Call IPQS API here
  -- TODO: Check IP reputation
  -- TODO: Verify email deliverability
  -- TODO: Detect VPN/proxy/datacenter
  
  RETURN QUERY SELECT 
    0 as risk_score,                    -- TODO: Get from IPQS
    false as is_vpn,                    -- TODO: Get from IPQS
    false as is_proxy,                  -- TODO: Get from IPQS
    false as is_disposable_email,       -- TODO: Get from IPQS
    'US'::TEXT as country_code,         -- TODO: Get from IPQS
    'pending'::TEXT as fraud_status;    -- Default to pending until IPQS integrated
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION check_fraud_signals IS 'PLACEHOLDER: Will integrate with IPQS for real-time fraud detection. Currently returns safe defaults.';

-- ============================================================================
-- 10. GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions on functions to authenticated users
GRANT EXECUTE ON FUNCTION record_seed_transaction TO authenticated;
GRANT EXECUTE ON FUNCTION award_signup_bonus TO authenticated;
GRANT EXECUTE ON FUNCTION award_verification_bonus TO authenticated;
GRANT EXECUTE ON FUNCTION award_referral_bonus TO authenticated;
GRANT EXECUTE ON FUNCTION process_email_verification TO authenticated;
GRANT EXECUTE ON FUNCTION check_fraud_signals TO authenticated;

-- ============================================================================
-- 11. VALIDATION QUERIES (Run these to test)
-- ============================================================================

-- Test 1: Check table exists
-- SELECT * FROM public.waitlist_signups LIMIT 1;

-- Test 2: Check indexes
-- SELECT indexname FROM pg_indexes WHERE tablename = 'waitlist_signups';

-- Test 3: Check RLS policies
-- SELECT * FROM pg_policies WHERE tablename = 'waitlist_signups';

-- Test 4: Test signup bonus
-- SELECT * FROM award_signup_bonus('YOUR_USER_ID_HERE');

-- Test 5: Test verification bonus
-- SELECT * FROM award_verification_bonus('YOUR_USER_ID_HERE');

-- Test 6: Test referral bonus
-- SELECT * FROM award_referral_bonus('REFERRER_ID', 'REFEREE_ID');

-- Test 7: Test full flow
-- SELECT * FROM process_email_verification('YOUR_USER_ID_HERE', 'REFERRER_ID');

-- ============================================================================
-- MIGRATION COMPLETE ✅
-- ============================================================================

-- Summary:
-- ✅ Created waitlist_signups table with fraud detection
-- ✅ Added indexes for performance
-- ✅ Configured RLS for security
-- ✅ Created helper function for seed transactions
-- ✅ Created separate reward functions (signup, verification, referral)
-- ✅ Created orchestrator function for email verification
-- ✅ Added fraud detection placeholder for future IPQS integration
-- ✅ Granted necessary permissions
-- ✅ Included validation test queries

-- Next Steps:
-- 1. Run this migration in Supabase SQL editor
-- 2. Test functions with validation queries
-- 3. Update JavaScript code to call these functions
-- 4. Integrate IPQS when ready (see check_fraud_signals function)