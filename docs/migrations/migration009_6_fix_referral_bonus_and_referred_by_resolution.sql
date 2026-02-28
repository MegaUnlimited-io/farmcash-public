-- ============================================================================
-- MIGRATION009.6 - Referral bonus reliability follow-up
--
-- Purpose:
-- 1) Fix referral bonus idempotency + overload ambiguity in award_referral_bonus
-- 2) Ensure process_email_verification resolves referrer when p_referred_by is NULL
--
-- Symptoms addressed:
-- - referred_by is set on referee, but referrer does not receive seeds
-- - retries can increment referral_count incorrectly
-- ============================================================================

CREATE OR REPLACE FUNCTION public.award_referral_bonus(
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
  v_reward_1st INTEGER;
  v_reward_2nd INTEGER;
  v_reward_3rd INTEGER;
  v_reward_ongoing INTEGER;
BEGIN
  -- Guard rails
  IF p_referrer_id IS NULL OR p_referee_id IS NULL THEN
    RETURN QUERY SELECT false, 0, 0, 0, 'Missing referrer/referee id'::TEXT;
    RETURN;
  END IF;

  IF p_referrer_id = p_referee_id THEN
    RETURN QUERY SELECT false, 0, 0, 0, 'Self-referral is not eligible'::TEXT;
    RETURN;
  END IF;

  -- Check if already awarded for this referee BEFORE changing referral_count
  SELECT EXISTS(
    SELECT 1
    FROM public.seed_transactions st
    WHERE st.user_id = p_referrer_id
      AND st.source = 'referral_reward'
      AND (st.metadata->>'referee_id')::uuid = p_referee_id
  ) INTO v_already_awarded;

  IF v_already_awarded THEN
    RETURN QUERY SELECT
      false,
      0,
      COALESCE((SELECT seeds_balance FROM public.users WHERE id = p_referrer_id), 0),
      COALESCE((SELECT referral_count FROM public.users WHERE id = p_referrer_id), 0),
      'Referral bonus already awarded for this user'::TEXT;
    RETURN;
  END IF;

  -- Lock + increment referral count atomically
  UPDATE public.users
  SET referral_count = referral_count + 1
  WHERE id = p_referrer_id
  RETURNING referral_count INTO v_referral_count;

  IF v_referral_count IS NULL THEN
    RETURN QUERY SELECT false, 0, 0, 0, 'Referrer user not found'::TEXT;
    RETURN;
  END IF;

  -- Dynamic reward config
  SELECT COALESCE((SELECT config_value::integer FROM public.app_config WHERE config_key = 'referral_reward_1st'), 200)
  INTO v_reward_1st;
  SELECT COALESCE((SELECT config_value::integer FROM public.app_config WHERE config_key = 'referral_reward_2nd'), 100)
  INTO v_reward_2nd;
  SELECT COALESCE((SELECT config_value::integer FROM public.app_config WHERE config_key = 'referral_reward_3rd'), 50)
  INTO v_reward_3rd;
  SELECT COALESCE((SELECT config_value::integer FROM public.app_config WHERE config_key = 'referral_reward_ongoing'), 0)
  INTO v_reward_ongoing;

  v_bonus_amount := CASE
    WHEN v_referral_count = 1 THEN v_reward_1st
    WHEN v_referral_count = 2 THEN v_reward_2nd
    WHEN v_referral_count = 3 THEN v_reward_3rd
    ELSE v_reward_ongoing
  END;

  -- Canonical 6-arg call (no overload ambiguity)
  v_new_balance := public.record_seed_transaction(
    p_referrer_id,
    v_bonus_amount,
    'referral_reward'::text,
    format('referral_%s%s', v_referral_count, CASE WHEN v_bonus_amount = 0 THEN '_unpaid' ELSE '' END)::text,
    jsonb_build_object(
      'awarded_at', now(),
      'referee_id', p_referee_id,
      'referral_number', v_referral_count,
      'bonus_amount', v_bonus_amount
    ),
    0
  );

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
    RETURN QUERY SELECT false, 0, 0, 0, SQLERRM::TEXT;
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
  v_referrer_id UUID;
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

  -- Resolve referrer from argument first, then from public.users.referred_by
  v_referrer_id := p_referred_by;
  IF v_referrer_id IS NULL THEN
    SELECT referred_by
    INTO v_referrer_id
    FROM public.users
    WHERE id = p_user_id;
  END IF;

  IF v_referrer_id IS NOT NULL THEN
    SELECT * INTO v_referral_result
    FROM public.award_referral_bonus(v_referrer_id, p_user_id);

    IF v_referral_result.success THEN
      v_breakdown := v_breakdown || jsonb_build_object(
        'referral_awarded_to_referrer', v_referral_result.seeds_awarded,
        'referrer_id', v_referrer_id,
        'referral_status', v_referral_result.message
      );
    ELSE
      v_breakdown := v_breakdown || jsonb_build_object(
        'referrer_id', v_referrer_id,
        'referral_status', v_referral_result.message
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
