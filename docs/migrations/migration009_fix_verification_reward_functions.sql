-- ============================================================================
-- MIGRATION009 - Fix verification reward function drift + idempotency flags
--
-- Why:
-- - Seed bonus functions drifted across migrations and no longer consistently
--   align with config-key naming and user-flag semantics.
-- - This migration hardens signup/verification reward awarding and ensures
--   public.users flags are updated atomically when bonuses are granted.
--
-- Scope:
-- - award_signup_bonus()
-- - award_verification_bonus()
-- - process_email_verification()
--
-- Notes:
-- - Standardizes config keys to canonical names:
--     signup_bonus_seeds
--     email_verification_bonus_seeds
-- - Removes legacy key aliases in this same migration.
-- - Tolerates environments where waitlist_signups row is absent.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 0) Canonicalize bonus config keys (Option B: standardize now)
-- ----------------------------------------------------------------------------
-- Canonical keys:
--   - signup_bonus_seeds
--   - email_verification_bonus_seeds
--
-- Legacy aliases removed by this migration:
--   - waitlist_bonus_seeds
--   - email_bonus_seeds

INSERT INTO public.app_config (config_key, config_value, value_type, description)
VALUES
  (
    'signup_bonus_seeds',
    COALESCE((SELECT config_value FROM public.app_config WHERE config_key = 'waitlist_bonus_seeds'), '100'),
    'integer',
    'Canonical signup bonus seeds amount awarded once at verification.'
  ),
  (
    'email_verification_bonus_seeds',
    COALESCE((SELECT config_value FROM public.app_config WHERE config_key = 'email_bonus_seeds'), '50'),
    'integer',
    'Canonical email verification bonus seeds amount awarded once.'
  )
ON CONFLICT (config_key) DO UPDATE SET
  config_value = EXCLUDED.config_value,
  value_type = EXCLUDED.value_type,
  description = EXCLUDED.description;

DELETE FROM public.app_config
WHERE config_key IN ('waitlist_bonus_seeds', 'email_bonus_seeds');

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
    'signup_bonus',
    'waitlist_signup',
    jsonb_build_object(
      'awarded_at', now(),
      'bonus_type', 'signup'
    )
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
    'email_verification',
    'email_confirmed',
    jsonb_build_object(
      'awarded_at', now(),
      'bonus_type', 'verification'
    )
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


CREATE OR REPLACE FUNCTION public.process_email_verification(
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
  v_breakdown JSONB := '{}'::jsonb;
BEGIN
  UPDATE public.waitlist_signups
  SET email_verified = true,
      email_verified_at = COALESCE(email_verified_at, now())
  WHERE user_id = p_user_id;

  SELECT * INTO v_signup_result
  FROM public.award_signup_bonus(p_user_id);

  IF v_signup_result.success THEN
    v_total_seeds := v_total_seeds + v_signup_result.seeds_awarded;
    v_breakdown := v_breakdown || jsonb_build_object('signup_bonus', v_signup_result.seeds_awarded);
  ELSE
    v_breakdown := v_breakdown || jsonb_build_object('signup_bonus_status', v_signup_result.message);
  END IF;

  SELECT * INTO v_verify_result
  FROM public.award_verification_bonus(p_user_id);

  IF v_verify_result.success THEN
    v_total_seeds := v_total_seeds + v_verify_result.seeds_awarded;
    v_breakdown := v_breakdown || jsonb_build_object('verification_bonus', v_verify_result.seeds_awarded);
  ELSE
    v_breakdown := v_breakdown || jsonb_build_object('verification_bonus_status', v_verify_result.message);
  END IF;

  IF p_referred_by IS NOT NULL THEN
    SELECT * INTO v_referral_result
    FROM public.award_referral_bonus(p_referred_by, p_user_id);

    IF v_referral_result.success AND v_referral_result.seeds_awarded > 0 THEN
      v_breakdown := v_breakdown || jsonb_build_object(
        'referral_awarded_to_referrer', v_referral_result.seeds_awarded,
        'referrer_id', p_referred_by
      );
    END IF;
  END IF;

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
