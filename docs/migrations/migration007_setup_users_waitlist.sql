-- ============================================================================
-- CLEAN SLATE: Drop all existing policies
-- ============================================================================

DROP POLICY IF EXISTS "Allow signup inserts" ON public.users;
DROP POLICY IF EXISTS "Users are viewable by everyone." ON public.users;
DROP POLICY IF EXISTS "Users can read their own record" ON public.users;
DROP POLICY IF EXISTS "Users can update their own record" ON public.users;

DROP POLICY IF EXISTS "Allow signup inserts" ON public.waitlist_signups;
DROP POLICY IF EXISTS "Users can read their own waitlist signup" ON public.waitlist_signups;

-- ============================================================================
-- PUBLIC.USERS - Secure Policies
-- ============================================================================

-- Allow new user creation (needed for ApparenceKit signup + waitlist)
CREATE POLICY "Allow user creation"
  ON public.users
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (auth.uid() = id);

-- Users can ONLY read their own record (no public access)
CREATE POLICY "Users can read own record"
  ON public.users
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- Users can update ONLY non-critical fields on their own record
CREATE POLICY "Users can update own profile"
  ON public.users
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (
    auth.uid() = id
    -- Prevent direct modification of critical balance fields
    AND (
      (seeds_balance IS NULL OR seeds_balance = (SELECT seeds_balance FROM public.users WHERE id = auth.uid()))
      AND (cash_balance IS NULL OR cash_balance = (SELECT cash_balance FROM public.users WHERE id = auth.uid()))
      AND (water_balance IS NULL OR water_balance = (SELECT water_balance FROM public.users WHERE id = auth.uid()))
      AND (referral_count IS NULL OR referral_count = (SELECT referral_count FROM public.users WHERE id = auth.uid()))
    )
  );

-- ============================================================================
-- PUBLIC.WAITLIST_SIGNUPS - Secure Policies
-- ============================================================================

-- Allow waitlist signup creation
CREATE POLICY "Allow waitlist signup"
  ON public.waitlist_signups
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (auth.uid() = user_id);

-- Users can read their own waitlist signup
CREATE POLICY "Users can read own waitlist signup"
  ON public.waitlist_signups
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Users can update their own waitlist signup (for email verification, migration status)
CREATE POLICY "Users can update own waitlist signup"
  ON public.waitlist_signups
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- Re-enable RLS (if not already enabled)
-- ============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waitlist_signups ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- move user creation serverside with creat_waitlist_user_complete
-- ============================================================================

CREATE OR REPLACE FUNCTION create_waitlist_user_complete(
  p_user_id UUID,
  p_email TEXT,
  p_game_type TEXT,
  p_rewarded_apps TEXT[],
  p_devices TEXT[],
  p_ip_address TEXT,
  p_timezone TEXT,
  p_browser TEXT,
  p_os TEXT,
  p_device_type TEXT,
  p_fingerprint_hash TEXT,
  p_referrer TEXT,
  p_referred_by UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referral_code TEXT;
  v_user_exists BOOLEAN;
BEGIN
  -- Check if user already exists in public.users
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id) INTO v_user_exists;
  
  IF v_user_exists THEN
    -- User exists (created by handle_new_user trigger), just get referral code and update flags
    SELECT referral_code INTO v_referral_code FROM public.users WHERE id = p_user_id;
    
    UPDATE public.users SET
      is_waitlist_user = true,
      referred_by = COALESCE(p_referred_by, referred_by)
    WHERE id = p_user_id;
    
  ELSE
    -- User doesn't exist, create manually with referral code
    -- Generate unique referral code (same pattern as handle_new_user)
    v_referral_code := substring(md5(random()::text || p_user_id::text) from 1 for 8);
    
    -- Ensure uniqueness (retry if collision, max 5 attempts)
    FOR i IN 1..5 LOOP
      IF NOT EXISTS (SELECT 1 FROM public.users WHERE referral_code = v_referral_code) THEN
        EXIT;
      END IF;
      v_referral_code := substring(md5(random()::text || p_user_id::text || i::text) from 1 for 8);
    END LOOP;
    
    -- Insert new user
    INSERT INTO public.users (
      id, 
      email, 
      referral_code, 
      is_waitlist_user, 
      referred_by,
      seeds_balance, 
      cash_balance, 
      water_balance, 
      user_level,
      total_harvests,
      experience_points
    ) VALUES (
      p_user_id, 
      p_email, 
      v_referral_code, 
      true, 
      p_referred_by,
      0,
      0.00,
      100,
      1,
      0,
      0
    );
  END IF;
  
  -- Create waitlist_signups record (always)
  INSERT INTO public.waitlist_signups (
    user_id, 
    email, 
    game_type, 
    rewarded_apps, 
    devices,
    ip_address, 
    timezone, 
    browser, 
    os, 
    device_type, 
    fingerprint_hash,
    referrer
  ) VALUES (
    p_user_id, 
    p_email, 
    p_game_type, 
    p_rewarded_apps, 
    p_devices,
    p_ip_address, 
    p_timezone, 
    p_browser, 
    p_os, 
    p_device_type, 
    p_fingerprint_hash,
    p_referrer
  );
  
  -- Return success with referral code
  RETURN jsonb_build_object(
    'success', true,
    'user_id', p_user_id,
    'email', p_email,
    'referral_code', v_referral_code
  );
  
EXCEPTION WHEN OTHERS THEN
  -- Return error
  RETURN jsonb_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$;


  -- Check referral code
CREATE OR REPLACE FUNCTION get_user_id_from_referral_code(p_referral_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
BEGIN
  SELECT id INTO v_user_id
  FROM public.users
  WHERE referral_code = p_referral_code;
  
  RETURN v_user_id;
END;
$$;