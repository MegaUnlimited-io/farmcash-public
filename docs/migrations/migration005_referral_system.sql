-- ============================================================================
-- MIGRATION005: Referral System for FarmCash
-- ============================================================================
-- Purpose: Add referral tracking to existing schema
-- Date: February 10, 2026
-- Author: Malcolm
-- Safe to re-run: YES (uses IF NOT EXISTS and conditional logic)
-- Rollback: Run MIGRATION005_ROLLBACK.sql if needed
-- ============================================================================

-- Start transaction for atomicity
BEGIN;

-- ============================================================================
-- STEP 1: Add Referral Columns to public.users
-- ============================================================================

DO $$
BEGIN
  -- Add referral_code column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'referral_code'
  ) THEN
    ALTER TABLE public.users ADD COLUMN referral_code TEXT;
    RAISE NOTICE '✅ Added referral_code column to public.users';
  ELSE
    RAISE NOTICE '⏭️  referral_code column already exists';
  END IF;

  -- Add referred_by column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'referred_by'
  ) THEN
    ALTER TABLE public.users ADD COLUMN referred_by UUID;
    RAISE NOTICE '✅ Added referred_by column to public.users';
  ELSE
    RAISE NOTICE '⏭️  referred_by column already exists';
  END IF;

  -- Add referral_count column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'referral_count'
  ) THEN
    ALTER TABLE public.users ADD COLUMN referral_count INTEGER DEFAULT 0;
    RAISE NOTICE '✅ Added referral_count column to public.users';
  ELSE
    RAISE NOTICE '⏭️  referral_count column already exists';
  END IF;

  -- Add is_waitlist_user column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'is_waitlist_user'
  ) THEN
    ALTER TABLE public.users ADD COLUMN is_waitlist_user BOOLEAN DEFAULT false;
    RAISE NOTICE '✅ Added is_waitlist_user column to public.users';
  ELSE
    RAISE NOTICE '⏭️  is_waitlist_user column already exists';
  END IF;

  -- Add waitlist_bonus_claimed column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'users' 
    AND column_name = 'waitlist_bonus_claimed'
  ) THEN
    ALTER TABLE public.users ADD COLUMN waitlist_bonus_claimed BOOLEAN DEFAULT false;
    RAISE NOTICE '✅ Added waitlist_bonus_claimed column to public.users';
  ELSE
    RAISE NOTICE '⏭️  waitlist_bonus_claimed column already exists';
  END IF;
END $$;

-- ============================================================================
-- STEP 2: Add Unique Constraint to referral_code
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_referral_code_unique'
  ) THEN
    ALTER TABLE public.users ADD CONSTRAINT users_referral_code_unique UNIQUE (referral_code);
    RAISE NOTICE '✅ Added unique constraint on referral_code';
  ELSE
    RAISE NOTICE '⏭️  Unique constraint on referral_code already exists';
  END IF;
END $$;

-- ============================================================================
-- STEP 3: Add Foreign Key for referred_by
-- ============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'users_referred_by_fkey'
  ) THEN
    ALTER TABLE public.users 
    ADD CONSTRAINT users_referred_by_fkey 
    FOREIGN KEY (referred_by) REFERENCES public.users(id) ON DELETE SET NULL;
    RAISE NOTICE '✅ Added foreign key constraint on referred_by';
  ELSE
    RAISE NOTICE '⏭️  Foreign key on referred_by already exists';
  END IF;
END $$;

-- ============================================================================
-- STEP 4: Create Indexes for Performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code);
CREATE INDEX IF NOT EXISTS idx_users_referred_by ON public.users(referred_by);
CREATE INDEX IF NOT EXISTS idx_users_is_waitlist ON public.users(is_waitlist_user);
CREATE INDEX IF NOT EXISTS idx_users_referral_count ON public.users(referral_count) WHERE referral_count > 0;

DO $$ BEGIN
  RAISE NOTICE '✅ Created indexes for referral columns';
END $$;

-- ============================================================================
-- STEP 5: Generate Referral Codes for Existing Users
-- ============================================================================

DO $$
DECLARE
  updated_count INTEGER;
BEGIN
  -- Generate unique referral codes for users who don't have one
  WITH updated_users AS (
    UPDATE public.users 
    SET referral_code = substring(md5(random()::text || id::text) from 1 for 8)
    WHERE referral_code IS NULL
    RETURNING id
  )
  SELECT COUNT(*) INTO updated_count FROM updated_users;
  
  RAISE NOTICE '✅ Generated referral codes for % existing users', updated_count;
END $$;

-- ============================================================================
-- STEP 6: Create public.referrals Audit Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  referee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  seeds_awarded INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  
  -- Ensure a user can only be referred once by same person
  UNIQUE(referrer_id, referee_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referee ON public.referrals(referee_id);
CREATE INDEX IF NOT EXISTS idx_referrals_created ON public.referrals(created_at);

DO $$ BEGIN
  RAISE NOTICE '✅ Created public.referrals table';
END $$;

-- Add table comment
COMMENT ON TABLE public.referrals IS 'Audit log of all referral events and seed rewards';

-- ============================================================================
-- STEP 7: Enable RLS on Referrals Table
-- ============================================================================

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if exists
DROP POLICY IF EXISTS "Users can view own referrals" ON public.referrals;

-- Create policy for users to view their own referrals
CREATE POLICY "Users can view own referrals"
ON public.referrals
FOR SELECT
USING (
  referrer_id = auth.uid()
  OR
  referee_id = auth.uid()
);

DO $$ BEGIN
  RAISE NOTICE '✅ Enabled RLS on referrals table';
END $$;

-- ============================================================================
-- STEP 8: Add Referral Config to app_config
-- ============================================================================

-- Insert referral reward configuration (if not exists)
INSERT INTO public.app_config (config_key, config_value, value_type, description)
VALUES 
  ('referral_reward_1st', '200', 'integer', 'Seeds awarded for 1st referral'),
  ('referral_reward_2nd', '100', 'integer', 'Seeds awarded for 2nd referral'),
  ('referral_reward_3rd', '50', 'integer', 'Seeds awarded for 3rd referral'),
  ('referral_reward_ongoing', '25', 'integer', 'Seeds awarded for 4th+ referrals'),
  ('waitlist_bonus_seeds', '100', 'integer', 'Bonus seeds for waitlist users on app launch'),
  ('referral_link_bonus', '50', 'integer', 'Seeds awarded for getting referral link')
ON CONFLICT (config_key) DO NOTHING;

DO $$ BEGIN
  RAISE NOTICE '✅ Added referral configuration to app_config';
END $$;

-- ============================================================================
-- STEP 9: Create credit_referrer() Function
-- ============================================================================

CREATE OR REPLACE FUNCTION credit_referrer()
RETURNS TRIGGER AS $$
DECLARE
  seed_reward INTEGER;
  referrer_count INTEGER;
BEGIN
  -- Only run if user was referred
  IF NEW.referred_by IS NOT NULL THEN
    
    -- Get referrer's current referral count
    SELECT referral_count INTO referrer_count
    FROM public.users
    WHERE id = NEW.referred_by;
    
    -- If referrer doesn't exist, exit gracefully
    IF referrer_count IS NULL THEN
      RETURN NEW;
    END IF;
    
    -- Determine seed reward based on config (with fallback defaults)
    SELECT 
      CASE 
        WHEN referrer_count = 0 THEN 
          COALESCE((SELECT config_value::integer FROM app_config WHERE config_key = 'referral_reward_1st'), 200)
        WHEN referrer_count = 1 THEN 
          COALESCE((SELECT config_value::integer FROM app_config WHERE config_key = 'referral_reward_2nd'), 100)
        WHEN referrer_count = 2 THEN 
          COALESCE((SELECT config_value::integer FROM app_config WHERE config_key = 'referral_reward_3rd'), 50)
        ELSE 
          COALESCE((SELECT config_value::integer FROM app_config WHERE config_key = 'referral_reward_ongoing'), 25)
      END
    INTO seed_reward;
    
    -- Credit seeds using existing update_user_seeds function
    PERFORM update_user_seeds(NEW.referred_by, seed_reward);
    
    -- Increment referrer's referral count
    UPDATE public.users
    SET referral_count = referral_count + 1
    WHERE id = NEW.referred_by;
    
    -- Log the referral in audit table
    INSERT INTO public.referrals (referrer_id, referee_id, seeds_awarded)
    VALUES (NEW.referred_by, NEW.id, seed_reward);
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
  RAISE NOTICE '✅ Created credit_referrer() function';
END $$;

COMMENT ON FUNCTION credit_referrer() IS 'Automatically credits referrer when new user signs up';

-- ============================================================================
-- STEP 10: Create Trigger on public.users for Referral Crediting
-- ============================================================================

DROP TRIGGER IF EXISTS on_user_referral_signup ON public.users;

CREATE TRIGGER on_user_referral_signup
AFTER INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION credit_referrer();

DO $$ BEGIN
  RAISE NOTICE '✅ Created trigger on_user_referral_signup';
END $$;

-- ============================================================================
-- STEP 11: Modify handle_new_user() to Support Referrals
-- ============================================================================

-- Update existing handle_new_user function to include referral code generation
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_referral_code TEXT;
BEGIN
  -- Generate unique referral code
  new_referral_code := substring(md5(random()::text || NEW.id::text) from 1 for 8);
  
  -- Ensure uniqueness (retry if collision, max 5 attempts)
  FOR i IN 1..5 LOOP
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE referral_code = new_referral_code) THEN
      EXIT;
    END IF;
    new_referral_code := substring(md5(random()::text || NEW.id::text || i::text) from 1 for 8);
  END LOOP;
  
  -- Insert user with referral code
  INSERT INTO public.users (
    id, 
    name, 
    avatar_url, 
    email, 
    referral_code,
    is_waitlist_user
  )
  VALUES (
    NEW.id, 
    NEW.raw_user_meta_data->>'name', 
    NEW.raw_user_meta_data->>'avatar_url', 
    NEW.email,
    new_referral_code,
    COALESCE(NEW.raw_user_meta_data->>'is_waitlist_user', 'false')::boolean
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
  RAISE NOTICE '✅ Updated handle_new_user() to include referral code generation';
END $$;

-- ============================================================================
-- STEP 12: Create claim_waitlist_bonus() Function
-- ============================================================================

CREATE OR REPLACE FUNCTION claim_waitlist_bonus(p_user_id UUID)
RETURNS TABLE(success BOOLEAN, seeds_awarded INTEGER, message TEXT) AS $$
DECLARE
  v_is_waitlist BOOLEAN;
  v_bonus_claimed BOOLEAN;
  v_bonus_amount INTEGER;
BEGIN
  -- Get bonus amount from config (default 100)
  SELECT COALESCE(
    (SELECT config_value::integer FROM app_config WHERE config_key = 'waitlist_bonus_seeds'),
    100
  ) INTO v_bonus_amount;
  
  -- Check if user is waitlist user and hasn't claimed bonus
  SELECT is_waitlist_user, waitlist_bonus_claimed 
  INTO v_is_waitlist, v_bonus_claimed
  FROM public.users
  WHERE id = p_user_id;
  
  -- Validate eligibility
  IF v_is_waitlist IS NULL THEN
    RETURN QUERY SELECT false, 0, 'User not found';
    RETURN;
  END IF;
  
  IF NOT v_is_waitlist THEN
    RETURN QUERY SELECT false, 0, 'User is not a waitlist member';
    RETURN;
  END IF;
  
  IF v_bonus_claimed THEN
    RETURN QUERY SELECT false, 0, 'Bonus already claimed';
    RETURN;
  END IF;
  
  -- Award bonus seeds
  PERFORM update_user_seeds(p_user_id, v_bonus_amount);
  
  -- Mark bonus as claimed
  UPDATE public.users
  SET waitlist_bonus_claimed = true
  WHERE id = p_user_id;
  
  -- Return success
  RETURN QUERY SELECT 
    true AS success,
    v_bonus_amount AS seeds_awarded,
    'Waitlist bonus claimed successfully! 🎉' AS message;
  
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 
      false AS success,
      0 AS seeds_awarded,
      SQLERRM AS message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
  RAISE NOTICE '✅ Created claim_waitlist_bonus() function';
END $$;

COMMENT ON FUNCTION claim_waitlist_bonus IS 'Awards one-time bonus to waitlist users on first app login';

-- ============================================================================
-- STEP 13: Create get_user_referral_info() Helper Function
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_referral_info(p_user_id UUID)
RETURNS TABLE(
  referral_code TEXT,
  referral_count INTEGER,
  seeds_balance INTEGER,
  is_waitlist_user BOOLEAN,
  waitlist_bonus_claimed BOOLEAN,
  referrals JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.referral_code,
    u.referral_count,
    u.seeds_balance,
    u.is_waitlist_user,
    u.waitlist_bonus_claimed,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'referee_id', r.referee_id,
          'seeds_awarded', r.seeds_awarded,
          'created_at', r.created_at
        ) ORDER BY r.created_at DESC
      ) FILTER (WHERE r.id IS NOT NULL),
      '[]'::jsonb
    ) as referrals
  FROM public.users u
  LEFT JOIN public.referrals r ON u.id = r.referrer_id
  WHERE u.id = p_user_id
  GROUP BY u.id, u.referral_code, u.referral_count, u.seeds_balance, u.is_waitlist_user, u.waitlist_bonus_claimed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DO $$ BEGIN
  RAISE NOTICE '✅ Created get_user_referral_info() function';
END $$;

COMMENT ON FUNCTION get_user_referral_info IS 'Returns complete referral information for a user';

-- ============================================================================
-- STEP 14: Create Analytics Views
-- ============================================================================

-- Top referrers leaderboard
CREATE OR REPLACE VIEW top_referrers AS
SELECT 
  u.id,
  u.name,
  u.referral_code,
  u.referral_count,
  u.seeds_balance,
  u.is_waitlist_user,
  u.creation_date,
  COUNT(r.id) as total_referrals_logged,
  COALESCE(SUM(r.seeds_awarded), 0) as total_seeds_earned_from_referrals
FROM public.users u
LEFT JOIN public.referrals r ON u.id = r.referrer_id
WHERE u.referral_count > 0
GROUP BY u.id, u.name, u.referral_code, u.referral_count, u.seeds_balance, u.is_waitlist_user, u.creation_date
ORDER BY u.referral_count DESC, total_seeds_earned_from_referrals DESC
LIMIT 100;

DO $$ BEGIN
  RAISE NOTICE '✅ Created top_referrers view';
END $$;

COMMENT ON VIEW top_referrers IS 'Leaderboard of top 100 users by referral count';

-- Referral statistics view
CREATE OR REPLACE VIEW referral_stats AS
SELECT 
  COUNT(DISTINCT CASE WHEN is_waitlist_user THEN id END) as waitlist_users,
  COUNT(DISTINCT CASE WHEN NOT is_waitlist_user THEN id END) as app_users,
  COUNT(DISTINCT id) as total_users,
  COUNT(DISTINCT CASE WHEN referred_by IS NOT NULL THEN id END) as referred_users,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN referred_by IS NOT NULL THEN id END) / NULLIF(COUNT(DISTINCT id), 0), 2) as referral_rate_percentage,
  SUM(referral_count) as total_referrals_made,
  ROUND(AVG(referral_count), 2) as avg_referrals_per_user,
  COUNT(DISTINCT CASE WHEN waitlist_bonus_claimed THEN id END) as waitlist_bonuses_claimed,
  COUNT(DISTINCT CASE WHEN is_waitlist_user AND NOT waitlist_bonus_claimed THEN id END) as waitlist_bonuses_pending
FROM public.users;

DO $$ BEGIN
  RAISE NOTICE '✅ Created referral_stats view';
END $$;

COMMENT ON VIEW referral_stats IS 'High-level referral program statistics';

-- ============================================================================
-- STEP 15: Verification and Final Checks
-- ============================================================================

DO $$
DECLARE
  column_count INTEGER;
  table_exists BOOLEAN;
  trigger_count INTEGER;
  function_count INTEGER;
BEGIN
  -- Verify columns added
  SELECT COUNT(*) INTO column_count
  FROM information_schema.columns 
  WHERE table_schema = 'public' 
  AND table_name = 'users' 
  AND column_name IN ('referral_code', 'referred_by', 'referral_count', 'is_waitlist_user', 'waitlist_bonus_claimed');
  
  IF column_count < 5 THEN
    RAISE EXCEPTION 'Not all columns were added to public.users (found % of 5)', column_count;
  END IF;
  
  -- Verify referrals table exists
  SELECT EXISTS (
    SELECT FROM pg_tables 
    WHERE schemaname = 'public' 
    AND tablename = 'referrals'
  ) INTO table_exists;
  
  IF NOT table_exists THEN
    RAISE EXCEPTION 'public.referrals table was not created';
  END IF;
  
  -- Verify trigger exists
  SELECT COUNT(*) INTO trigger_count
  FROM pg_trigger
  WHERE tgname = 'on_user_referral_signup';
  
  IF trigger_count = 0 THEN
    RAISE EXCEPTION 'on_user_referral_signup trigger was not created';
  END IF;
  
  -- Verify functions exist
  SELECT COUNT(*) INTO function_count
  FROM pg_proc
  WHERE proname IN ('credit_referrer', 'claim_waitlist_bonus', 'get_user_referral_info');
  
  IF function_count < 3 THEN
    RAISE EXCEPTION 'Not all referral functions were created (found % of 3)', function_count;
  END IF;
  
  RAISE NOTICE '✅ All verification checks passed';
END $$;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

COMMIT;

DO $$
BEGIN
  RAISE NOTICE '
  ============================================================
  ✅ MIGRATION005: Referral System - COMPLETE
  ============================================================
  
  Columns added to public.users:
  ✓ referral_code (TEXT UNIQUE)
  ✓ referred_by (UUID, FK to users)
  ✓ referral_count (INTEGER)
  ✓ is_waitlist_user (BOOLEAN)
  ✓ waitlist_bonus_claimed (BOOLEAN)
  
  Tables created:
  ✓ public.referrals (audit log)
  
  Functions created:
  ✓ credit_referrer() - Auto-credit on signup
  ✓ claim_waitlist_bonus() - Award early adopter bonus
  ✓ get_user_referral_info() - Get user referral data
  
  Functions updated:
  ✓ handle_new_user() - Now generates referral codes
  
  Views created:
  ✓ top_referrers - Leaderboard
  ✓ referral_stats - Program metrics
  
  Configuration added:
  ✓ Referral reward amounts in app_config
  
  Next steps:
  1. Build landing page at /referral
  2. Test referral flow end-to-end
  3. Deploy and start user acquisition
  
  To rollback this migration, run MIGRATION005_ROLLBACK.sql
  ============================================================
  ';
END $$;
