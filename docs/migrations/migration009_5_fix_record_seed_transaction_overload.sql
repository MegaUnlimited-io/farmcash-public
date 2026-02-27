-- ============================================================================
-- MIGRATION009.5 - Follow-up patch for environments that already ran MIGRATION009
--
-- Purpose:
-- - Resolve record_seed_transaction overload ambiguity in reward functions.
-- - Safe to run after initial migration009.
--
-- Root issue observed in prod logs:
--   function public.record_seed_transaction(uuid, integer, unknown, unknown, jsonb) is not unique
-- ============================================================================

-- 1) Keep exactly one canonical record_seed_transaction signature (6 args)
DROP FUNCTION IF EXISTS public.record_seed_transaction(uuid, integer, text, text, jsonb);

CREATE OR REPLACE FUNCTION public.record_seed_transaction(
  p_user_id    uuid,
  p_amount     integer,
  p_source     text,
  p_reference  text,
  p_metadata   jsonb   DEFAULT '{}'::jsonb,
  p_xp_granted integer DEFAULT 0
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_balance integer;
BEGIN
  UPDATE public.users
  SET seeds_balance = seeds_balance + p_amount
  WHERE id = p_user_id
  RETURNING seeds_balance INTO v_new_balance;

  INSERT INTO public.seed_transactions (
    user_id, amount, source, reference, balance_after, metadata, xp_granted
  ) VALUES (
    p_user_id, p_amount, p_source, p_reference,
    v_new_balance, p_metadata, p_xp_granted
  );

  RETURN v_new_balance;
END;
$$;

-- 2) Force reward functions to call canonical 6-arg signature explicitly
CREATE OR REPLACE FUNCTION public.award_signup_bonus(
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
  SELECT COALESCE(
    (SELECT config_value::integer FROM public.app_config WHERE config_key = 'signup_bonus_seeds'),
    100
  ) INTO v_bonus_amount;

  SELECT (
    COALESCE((SELECT waitlist_bonus_claimed FROM public.users WHERE id = p_user_id), false)
    OR EXISTS (
      SELECT 1 FROM public.seed_transactions
      WHERE user_id = p_user_id
        AND source IN ('signup_bonus', 'waitlist_bonus')
    )
  ) INTO v_already_awarded;

  IF v_already_awarded THEN
    RETURN QUERY SELECT
      false,
      0,
      COALESCE((SELECT seeds_balance FROM public.users WHERE id = p_user_id), 0),
      'Signup bonus already claimed'::TEXT;
    RETURN;
  END IF;

  v_new_balance := public.record_seed_transaction(
    p_user_id,
    v_bonus_amount,
    'signup_bonus'::text,
    'waitlist_signup'::text,
    jsonb_build_object(
      'awarded_at', now(),
      'bonus_type', 'signup'
    ),
    0
  );

  UPDATE public.users
  SET waitlist_bonus_claimed = true
  WHERE id = p_user_id;

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
      COALESCE((SELECT seeds_balance FROM public.users WHERE id = p_user_id), 0),
      SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


CREATE OR REPLACE FUNCTION public.award_verification_bonus(
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
  v_waitlist_verified BOOLEAN;
  v_auth_verified BOOLEAN;
BEGIN
  SELECT COALESCE(
    (SELECT config_value::integer FROM public.app_config WHERE config_key = 'email_verification_bonus_seeds'),
    50
  ) INTO v_bonus_amount;

  SELECT COALESCE(w.email_verified, false)
  INTO v_waitlist_verified
  FROM public.waitlist_signups w
  WHERE w.user_id = p_user_id
  LIMIT 1;

  SELECT (au.email_confirmed_at IS NOT NULL)
  INTO v_auth_verified
  FROM auth.users au
  WHERE au.id = p_user_id;

  IF NOT COALESCE(v_waitlist_verified, false) AND NOT COALESCE(v_auth_verified, false) THEN
    RETURN QUERY SELECT
      false,
      0,
      COALESCE((SELECT seeds_balance FROM public.users WHERE id = p_user_id), 0),
      'Email not verified yet'::TEXT;
    RETURN;
  END IF;

  SELECT (
    COALESCE((SELECT email_verified_bonus_claimed FROM public.users WHERE id = p_user_id), false)
    OR EXISTS (
      SELECT 1 FROM public.seed_transactions
      WHERE user_id = p_user_id
        AND source = 'email_verification'
    )
  ) INTO v_already_awarded;

  IF v_already_awarded THEN
    RETURN QUERY SELECT
      false,
      0,
      COALESCE((SELECT seeds_balance FROM public.users WHERE id = p_user_id), 0),
      'Verification bonus already claimed'::TEXT;
    RETURN;
  END IF;

  v_new_balance := public.record_seed_transaction(
    p_user_id,
    v_bonus_amount,
    'email_verification'::text,
    'email_confirmed'::text,
    jsonb_build_object(
      'awarded_at', now(),
      'bonus_type', 'verification'
    ),
    0
  );

  UPDATE public.users
  SET email_verified_bonus_claimed = true
  WHERE id = p_user_id;

  UPDATE public.waitlist_signups
  SET email_verified = true,
      email_verified_at = COALESCE(email_verified_at, now()),
      fraud_status = CASE WHEN fraud_status = 'pending' THEN 'approved' ELSE fraud_status END
  WHERE user_id = p_user_id;

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
      COALESCE((SELECT seeds_balance FROM public.users WHERE id = p_user_id), 0),
      SQLERRM::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
