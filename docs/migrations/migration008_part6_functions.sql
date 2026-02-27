-- ============================================================================
-- MIGRATION008 - Part 6: Functions
-- Run LAST — depends on schema + data from Parts 1-5.
--
-- DROPPED:    update_user_progression (broken formula, replaced by award_xp)
-- MODIFIED:   record_seed_transaction, grant_initial_seeds, handle_new_user,
--             create_initial_farm_for_user, process_postback,
--             test_harvest_crop, test_create_crops, create_waitlist_user_complete
-- NEW:        roll_yield, award_xp, unlock_plot
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DROP obsolete function
-- Was using wrong formula (SQRT-based), referenced old column names.
-- Replaced entirely by award_xp().
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.update_user_progression(uuid, integer);


-- ============================================================================
-- MODIFIED FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- record_seed_transaction
-- CHANGE: Added p_xp_granted (default 0) — passed to seed_transactions.xp_granted
-- All existing callers are unaffected (parameter is optional, defaults to 0).
-- ----------------------------------------------------------------------------
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


-- ----------------------------------------------------------------------------
-- grant_initial_seeds
-- CHANGE: source 'signup_bonus' → 'demo_seeds'
-- Fixes collision with award_signup_bonus() idempotency check
-- (which looks for source='signup_bonus' to prevent double-awards).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.grant_initial_seeds(user_id_param uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  starting_seeds integer;
BEGIN
  SELECT config_value::integer INTO starting_seeds
  FROM public.app_config
  WHERE config_key = 'demo_seeds';

  starting_seeds := COALESCE(starting_seeds, 100);

  UPDATE public.users
  SET seeds_balance = starting_seeds
  WHERE id = user_id_param
    AND (seeds_balance IS NULL OR seeds_balance = 0);

  IF FOUND THEN
    INSERT INTO public.seed_transactions (
      user_id, amount, source, reference, balance_after
    ) VALUES (
      user_id_param, starting_seeds, 'demo_seeds', 'initial_grant', starting_seeds
    );
    RETURN starting_seeds;
  END IF;

  RETURN 0;
END;
$$;


-- ----------------------------------------------------------------------------
-- handle_new_user (trigger function)
-- CHANGE: Explicit level=1, xp=0 on INSERT (renamed from user_level/experience_points)
-- CHANGE: Added referral code generation (was missing for non-waitlist signups)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_farm_id     uuid;
  seeds_granted   integer;
  v_referral_code text;
  i               integer;
BEGIN
  -- Generate unique 8-char referral code
  v_referral_code := substring(md5(random()::text || NEW.id::text) from 1 for 8);
  FOR i IN 1..5 LOOP
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.users WHERE referral_code = v_referral_code
    );
    v_referral_code :=
      substring(md5(random()::text || NEW.id::text || i::text) from 1 for 8);
  END LOOP;

  -- Create public.users record with explicit level/xp defaults
  INSERT INTO public.users (id, name, avatar_url, email, level, xp, referral_code)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'name',
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.email,
    1,
    0,
    v_referral_code
  );

  -- Create farm + grant starter plots 0-5
  BEGIN
    SELECT public.create_initial_farm_for_user(NEW.id) INTO new_farm_id;
    RAISE NOTICE 'Farm created: %', new_farm_id;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to create farm for %: %', NEW.id, SQLERRM;
  END;

  -- Grant demo seeds
  BEGIN
    SELECT public.grant_initial_seeds(NEW.id) INTO seeds_granted;
    RAISE NOTICE 'Seeds granted: %', seeds_granted;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to grant seeds for %: %', NEW.id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;


-- ----------------------------------------------------------------------------
-- create_initial_farm_for_user
-- CHANGE: Also inserts plots 0-5 into user_unlocked_plots (free Level 1 plots)
-- CHANGE: max_plots starts at 6 (not 15 — grows as rows are unlocked)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_initial_farm_for_user(user_id_param uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  farm_id uuid;
BEGIN
  INSERT INTO public.user_farms (user_id, farm_name, max_plots)
  VALUES (user_id_param, 'My Farm', 6)
  ON CONFLICT (user_id) DO NOTHING
  RETURNING id INTO farm_id;

  IF farm_id IS NULL THEN
    SELECT id INTO farm_id
    FROM public.user_farms WHERE user_id = user_id_param;
  END IF;

  -- Grant starter plots 0-5 (rows 1+2, free at Level 1)
  INSERT INTO public.user_unlocked_plots (user_id, plot_id)
  SELECT user_id_param, generate_series(0, 5)
  ON CONFLICT (user_id, plot_id) DO NOTHING;

  RETURN farm_id;
END;
$$;


-- ----------------------------------------------------------------------------
-- create_waitlist_user_complete
-- CHANGE: Updated column references user_level → level, experience_points → xp
-- (Only the INSERT branch needed updating — UPDATE branch didn't touch these)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_waitlist_user_complete(
  p_user_id         uuid,
  p_email           text,
  p_game_type       text,
  p_rewarded_apps   text[],
  p_devices         text[],
  p_ip_address      text,
  p_timezone        text,
  p_browser         text,
  p_os              text,
  p_device_type     text,
  p_fingerprint_hash text,
  p_referrer        text,
  p_referred_by     uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_referral_code text;
  v_user_exists   boolean;
  i               integer;
BEGIN
  SELECT EXISTS(SELECT 1 FROM public.users WHERE id = p_user_id)
  INTO v_user_exists;

  IF v_user_exists THEN
    -- User already exists (created by handle_new_user trigger)
    SELECT referral_code INTO v_referral_code
    FROM public.users WHERE id = p_user_id;

    UPDATE public.users SET
      is_waitlist_user = true,
      referred_by      = COALESCE(p_referred_by, referred_by)
    WHERE id = p_user_id;

  ELSE
    -- User doesn't exist — create manually
    v_referral_code :=
      substring(md5(random()::text || p_user_id::text) from 1 for 8);

    FOR i IN 1..5 LOOP
      EXIT WHEN NOT EXISTS (
        SELECT 1 FROM public.users WHERE referral_code = v_referral_code
      );
      v_referral_code :=
        substring(md5(random()::text || p_user_id::text || i::text) from 1 for 8);
    END LOOP;

    INSERT INTO public.users (
      id, email, referral_code, is_waitlist_user, referred_by,
      seeds_balance, cash_balance, water_balance,
      level, xp,                         -- ← renamed from user_level/experience_points
      total_harvests
    ) VALUES (
      p_user_id, p_email, v_referral_code, true, p_referred_by,
      0, 0.00, 100,
      1, 0,
      0
    );
  END IF;

  -- Create waitlist_signups record
  INSERT INTO public.waitlist_signups (
    user_id, email, game_type, rewarded_apps, devices,
    ip_address, timezone, browser, os, device_type,
    fingerprint_hash, referrer
  ) VALUES (
    p_user_id, p_email, p_game_type, p_rewarded_apps, p_devices,
    p_ip_address, p_timezone, p_browser, p_os, p_device_type,
    p_fingerprint_hash, p_referrer
  );

  RETURN jsonb_build_object(
    'success',       true,
    'user_id',       p_user_id,
    'email',         p_email,
    'referral_code', v_referral_code
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


-- ----------------------------------------------------------------------------
-- process_postback
-- CHANGE 1: source 'POSTBACK' → 'offer_completion', 'REVERSAL' → 'reversal'
-- CHANGE 2: xp_granted added to seed_transactions insert
-- CHANGE 3: award_xp() called after successful offer completion
-- CHANGE 4: Returns xp_granted in response payload
--
-- TODO: CLAWBACK PATH
-- When p_status = 'reversed':
--   - Seeds ARE deducted (p_currency passed as negative from OCG caller)
--   - XP is NOT deducted — users keep progression permanently
--   - If reversal amount is large, insert into fraud_events for review
--   - Consider auto-flagging accounts with multiple reversals
--   - Implementation target: Week 3 (when OCG live integration is built)
--   - Functions to update: process_postback (here), fraud_events INSERT
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_postback(
  p_partner    character varying,
  p_action_id  character varying,
  p_user_id    uuid,
  p_currency   integer,
  p_offer_id   character varying,
  p_offer_name text,
  p_status     character varying,
  p_commission numeric,
  p_raw_params jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_duplicate            boolean;
  v_balance_before       integer;
  v_balance_after        integer;
  v_postback_id          uuid;
  v_transaction_id       uuid;
  v_existing_postback_id uuid;
  v_xp_granted           integer := 0;
  v_source               text;
BEGIN
  -- Step 1: Deduplication check
  SELECT EXISTS (
    SELECT 1 FROM postback_deduplication
    WHERE partner    = p_partner
      AND action_id  = p_action_id
      AND processed_at > NOW() - INTERVAL '90 days'
  ) INTO v_duplicate;

  IF v_duplicate THEN
    UPDATE postback_log
    SET duplicate_attempts = duplicate_attempts + 1,
        last_duplicate_at  = NOW()
    WHERE partner   = p_partner
      AND action_id = p_action_id
    RETURNING id INTO v_existing_postback_id;

    RETURN jsonb_build_object(
      'success',     false,
      'reason',      'DUPLICATE',
      'action_id',   p_action_id,
      'postback_id', v_existing_postback_id,
      'message',     'Duplicate postback logged and counted'
    );
  END IF;

  -- Step 2: Record deduplication
  INSERT INTO postback_deduplication (partner, action_id)
  VALUES (p_partner, p_action_id);

  -- Step 3: Validate user exists
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'User not found in auth.users: %', p_user_id;
  END IF;

  -- Step 4: Lock user row + get balance
  SELECT seeds_balance INTO v_balance_before
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found in public.users: %', p_user_id;
  END IF;

  -- Step 5: Determine source and XP
  IF p_status = 'reversed' THEN
    v_source     := 'reversal';
    v_xp_granted := 0;
    -- TODO: CLAWBACK PATH — see header comment above
  ELSE
    v_source     := 'offer_completion';
    v_xp_granted := p_currency;  -- XP = seeds earned, 1:1
  END IF;

  -- Step 6: Update seed balance
  UPDATE public.users
  SET seeds_balance = seeds_balance + p_currency
  WHERE id = p_user_id
  RETURNING seeds_balance INTO v_balance_after;

  -- Step 7: Log seed transaction (includes XP audit field)
  INSERT INTO seed_transactions (
    user_id, source, amount, balance_after, reference, metadata, xp_granted
  ) VALUES (
    p_user_id,
    v_source,
    p_currency,
    v_balance_after,
    p_action_id,
    jsonb_build_object(
      'partner',    p_partner,
      'offer_id',   p_offer_id,
      'offer_name', p_offer_name,
      'commission', p_commission
    ),
    v_xp_granted
  ) RETURNING id INTO v_transaction_id;

  -- Step 8: Award XP (offer completions only — reversals do NOT deduct XP)
  IF p_status != 'reversed' THEN
    PERFORM award_xp(p_user_id, p_currency);
  END IF;

  -- Step 9: Log postback
  INSERT INTO postback_log (
    partner, action_id, user_id, offer_id, offer_name,
    currency_amount, status, commission, response_code,
    response_body, raw_params, duplicate_attempts
  ) VALUES (
    p_partner, p_action_id, p_user_id, p_offer_id, p_offer_name,
    p_currency, p_status, p_commission, 200,
    'Success', p_raw_params, 0
  ) RETURNING id INTO v_postback_id;

  -- Step 10: Return
  RETURN jsonb_build_object(
    'success',            true,
    'action_id',          p_action_id,
    'postback_id',        v_postback_id,
    'transaction_id',     v_transaction_id,
    'old_balance',        v_balance_before,
    'new_balance',        v_balance_after,
    'transaction_amount', p_currency,
    'xp_granted',         v_xp_granted
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', false,
    'reason',  'INTERNAL_ERROR',
    'error',   SQLERRM
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- test_create_crops
-- CHANGE: Seed cost now read from crop_types.seed_cost (was hardcoded CASE with
--         wrong values: 25/50/100/200 — actual values now 12/24/100/200)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.test_create_crops(
  p_farm_id      uuid,
  p_crop_type_id integer DEFAULT 1,
  p_num_plots    integer DEFAULT 6
)
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
  v_max_plots       integer;
  v_occupied_plots  integer;
  v_available_plots integer;
  v_crop_name       text;
  v_growth_hours    integer;
  v_seed_cost       integer;
  v_planted_count   integer := 0;
  v_plot_position   integer;
  v_result          json;
BEGIN
  SELECT max_plots INTO v_max_plots
  FROM user_farms WHERE id = p_farm_id;

  IF v_max_plots IS NULL THEN
    RAISE EXCEPTION 'Farm not found: %', p_farm_id;
  END IF;

  SELECT COUNT(*) INTO v_occupied_plots
  FROM crops
  WHERE user_farm_id = p_farm_id AND harvested_at IS NULL;

  v_available_plots := v_max_plots - v_occupied_plots;

  IF p_num_plots > v_available_plots THEN
    RAISE EXCEPTION
      'Not enough plots! Requested: %, Available: %, Occupied: %/%',
      p_num_plots, v_available_plots, v_occupied_plots, v_max_plots;
  END IF;

  -- Dynamic lookup (no more hardcoded seed costs)
  SELECT name, growth_time_hours, seed_cost
  INTO v_crop_name, v_growth_hours, v_seed_cost
  FROM crop_types WHERE id = p_crop_type_id;

  IF v_crop_name IS NULL THEN
    RAISE EXCEPTION
      'Invalid crop_type_id: %. Valid IDs: 1=Tomato, 2=Eggplant, 3=Corn, 4=GoldenMelon',
      p_crop_type_id;
  END IF;

  FOR i IN 0..(p_num_plots - 1) LOOP
    SELECT pos INTO v_plot_position
    FROM generate_series(0, v_max_plots - 1) pos
    WHERE pos NOT IN (
      SELECT plot_position FROM crops
      WHERE user_farm_id = p_farm_id AND harvested_at IS NULL
    )
    ORDER BY pos LIMIT 1;

    INSERT INTO crops (
      user_farm_id, crop_type_id, plot_position,
      planted_at, harvest_ready_at, seeds_invested, status
    ) VALUES (
      p_farm_id, p_crop_type_id, v_plot_position,
      NOW(), NOW() + (v_growth_hours || ' hours')::interval,
      v_seed_cost, 'growing'
    );

    v_planted_count := v_planted_count + 1;
  END LOOP;

  RETURN json_build_object(
    'success',           true,
    'planted_count',     v_planted_count,
    'crop_type',         v_crop_name,
    'seed_cost_each',    v_seed_cost,
    'growth_time_hours', v_growth_hours,
    'ready_at',          NOW() + (v_growth_hours || ' hours')::interval,
    'plots_used',        (v_occupied_plots + v_planted_count)::text || '/' || v_max_plots::text
  );
END;
$$;


-- ----------------------------------------------------------------------------
-- test_harvest_crop
-- CHANGE: Removed p_cash_amount parameter (was hardcoded by caller)
--         Now calculates cash internally: roll_yield() + base_rate from app_config
--         Formula: ROUND((seeds_invested / base_rate) * yield_multiplier, 2)
--         Returns yield_tier and yield_label so Flutter can show harvest feedback
--
-- ⚠️  Flutter testing page must be updated: remove p_cash_amount argument
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.test_harvest_crop(p_crop_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id          uuid;
  v_seeds_invested   integer;
  v_crop_type_id     integer;
  v_crop_name        text;
  v_base_rate        numeric;
  v_yield            record;
  v_cash_amount      numeric;
  v_new_cash_balance numeric;
BEGIN
  -- Get crop details + user
  SELECT
    uf.user_id,
    c.seeds_invested,
    c.crop_type_id,
    ct.name
  INTO v_user_id, v_seeds_invested, v_crop_type_id, v_crop_name
  FROM public.crops c
  JOIN public.user_farms  uf ON uf.id = c.user_farm_id
  JOIN public.crop_types  ct ON ct.id = c.crop_type_id
  WHERE c.id = p_crop_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Crop not found: %', p_crop_id;
  END IF;

  -- Get base rate (seeds per $1)
  SELECT config_value::numeric INTO v_base_rate
  FROM public.app_config WHERE config_key = 'base_rate';
  v_base_rate := COALESCE(v_base_rate, 250);

  -- Roll yield tier
  SELECT * INTO v_yield FROM public.roll_yield(v_crop_type_id);

  -- Calculate cash: ROUND((seeds / base_rate) * multiplier, 2)
  -- Standard rounding: 0.5+ rounds up, 0.4 rounds down
  v_cash_amount := ROUND(
    (v_seeds_invested::numeric / v_base_rate) * v_yield.yield_multiplier,
    2
  );

  -- Credit cash to user
  UPDATE public.users
  SET cash_balance = cash_balance + v_cash_amount
  WHERE id = v_user_id
  RETURNING cash_balance INTO v_new_cash_balance;

  -- Mark crop harvested
  UPDATE public.crops
  SET
    harvested_at     = NOW(),
    status           = 'harvested',
    final_cash_value = v_cash_amount,
    yield_multiplier = v_yield.yield_multiplier
  WHERE id = p_crop_id;

  -- Append harvest history
  INSERT INTO public.harvest_history (
    user_farm_id, crop_type_id, seeds_invested, cash_earned,
    growth_time_actual, yield_percentage, plot_position, harvested_at
  )
  SELECT
    c.user_farm_id,
    c.crop_type_id,
    c.seeds_invested,
    v_cash_amount,
    NOW() - c.planted_at,
    ROUND(v_yield.yield_multiplier * 100)::integer,
    c.plot_position,
    NOW()
  FROM public.crops c
  WHERE c.id = p_crop_id;

  RETURN jsonb_build_object(
    'success',          true,
    'cash_earned',      v_cash_amount,
    'new_cash_balance', v_new_cash_balance,
    'seeds_invested',   v_seeds_invested,
    'crop_name',        v_crop_name,
    'yield_tier',       v_yield.tier,
    'yield_label',      v_yield.tier_label,
    'yield_multiplier', v_yield.yield_multiplier
  );
END;
$$;


-- ============================================================================
-- NEW FUNCTIONS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- roll_yield(p_crop_type_id)
-- Returns yield multiplier, display label, and tier key for a given crop.
-- Uses p1-p4 from crop_types (probability weights per crop).
-- Uses y1-y4 from app_config (universal multiplier values).
-- Called by: test_harvest_crop() — and future production harvest_crop().
--
-- Weighted random selection: roll 0-1, walk cumulative probabilities.
-- Y4 (Golden Harvest) catches any remainder to handle floating point edge cases.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.roll_yield(p_crop_type_id integer)
RETURNS TABLE(
  yield_multiplier  numeric,
  tier_label        text,
  tier              text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_p1 numeric; v_p2 numeric; v_p3 numeric; v_p4 numeric;
  v_y1 numeric; v_y2 numeric; v_y3 numeric; v_y4 numeric;
  v_roll       numeric;
  v_cumulative numeric;
BEGIN
  -- Get this crop's probability weights
  SELECT ct.p1, ct.p2, ct.p3, ct.p4
  INTO v_p1, v_p2, v_p3, v_p4
  FROM public.crop_types ct
  WHERE ct.id = p_crop_type_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Crop type not found: %', p_crop_type_id;
  END IF;

  -- Get universal yield multipliers from config
  SELECT
    (SELECT config_value::numeric FROM public.app_config WHERE config_key = 'y1'),
    (SELECT config_value::numeric FROM public.app_config WHERE config_key = 'y2'),
    (SELECT config_value::numeric FROM public.app_config WHERE config_key = 'y3'),
    (SELECT config_value::numeric FROM public.app_config WHERE config_key = 'y4')
  INTO v_y1, v_y2, v_y3, v_y4;

  -- Roll
  v_roll := random();  -- [0, 1)

  -- Walk cumulative probability bands
  v_cumulative := v_p1;
  IF v_roll < v_cumulative THEN
    RETURN QUERY SELECT v_y1, 'Speedy Harvest'::text, 'y1'::text; RETURN;
  END IF;

  v_cumulative := v_cumulative + v_p2;
  IF v_roll < v_cumulative THEN
    RETURN QUERY SELECT v_y2, 'Standard Harvest'::text, 'y2'::text; RETURN;
  END IF;

  v_cumulative := v_cumulative + v_p3;
  IF v_roll < v_cumulative THEN
    RETURN QUERY SELECT v_y3, 'Bountiful Harvest'::text, 'y3'::text; RETURN;
  END IF;

  -- Y4 catches all remainder (including float edge cases where sum = 0.9999...)
  -- Note: For crops where p4=0.00, this path is unreachable in practice
  -- (cumulative will equal 1.0 after p3 band). The fallback is safe.
  RETURN QUERY SELECT v_y4, 'Golden Harvest'::text, 'y4'::text;
END;
$$;


-- ----------------------------------------------------------------------------
-- award_xp(p_user_id, p_amount)
-- Awards XP, checks levels table for level-up, sets watering_unlocked if earned.
-- Handles multiple level-ups from a single large XP grant.
-- Returns: new totals + level-up payload for Flutter to show level-up modal.
--
-- Called by: process_postback() (after offer completion)
-- XP is NEVER deducted — not on clawbacks, not on bans.
-- If fraud is confirmed → account banned → XP irrelevant.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.award_xp(p_user_id uuid, p_amount integer)
RETURNS TABLE(
  new_xp        integer,
  new_level     integer,
  leveled_up    boolean,
  level_up_data jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current_xp        integer;
  v_current_level     integer;
  v_watering_unlocked boolean;
  v_new_xp            integer;
  v_new_level         integer;
  v_leveled_up        boolean := false;
  v_level_up_data     jsonb   := '[]'::jsonb;
  v_level_record      record;
BEGIN
  -- Lock row to prevent concurrent XP grants causing level-up races
  SELECT xp, level, watering_unlocked
  INTO v_current_xp, v_current_level, v_watering_unlocked
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;

  v_new_xp    := v_current_xp + p_amount;
  v_new_level := v_current_level;

  -- Check all level thresholds crossed by this XP gain (handles multi-level-up)
  FOR v_level_record IN
    SELECT
      l.*,
      ct.display_name AS crop_display_name
    FROM public.levels l
    LEFT JOIN public.crop_types ct ON ct.id = l.crop_unlock_id
    WHERE l.xp_threshold <= v_new_xp
      AND l.level        >  v_current_level
    ORDER BY l.level ASC
  LOOP
    v_new_level  := v_level_record.level;
    v_leveled_up := true;

    -- Build level-up payload array (Flutter reads this to show modal)
    v_level_up_data := v_level_up_data || jsonb_build_array(
      jsonb_build_object(
        'level',            v_level_record.level,
        'label',            v_level_record.label,
        'crop_unlock_id',   v_level_record.crop_unlock_id,
        'crop_name',        v_level_record.crop_display_name,
        'row_unlock',       v_level_record.row_unlock,
        'unlocks_watering', v_level_record.unlocks_watering
      )
    );

    -- Unlock watering if this level grants it
    IF v_level_record.unlocks_watering THEN
      v_watering_unlocked := true;
    END IF;
  END LOOP;

  -- Persist
  UPDATE public.users
  SET
    xp                = v_new_xp,
    level             = v_new_level,
    watering_unlocked = v_watering_unlocked
  WHERE id = p_user_id;

  RETURN QUERY SELECT v_new_xp, v_new_level, v_leveled_up, v_level_up_data;
END;
$$;


-- ----------------------------------------------------------------------------
-- unlock_plot(p_user_id, p_plot_id)
-- User purchases a specific plot.
-- Validates: level gate, not already unlocked, sufficient seeds.
-- Deducts seeds and logs transaction. Free plots (cost=0) skip deduction.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.unlock_plot(p_user_id uuid, p_plot_id integer)
RETURNS TABLE(
  success           boolean,
  seeds_spent       integer,
  new_seeds_balance integer,
  message           text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_level  integer;
  v_user_seeds  integer;
  v_row         record;
  v_cost        integer;
  v_new_balance integer;
BEGIN
  -- Lock user row
  SELECT level, seeds_balance
  INTO v_user_level, v_user_seeds
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0, 0, 'User not found'::text; RETURN;
  END IF;

  -- Validate range
  IF p_plot_id < 0 OR p_plot_id > 23 THEN
    RETURN QUERY
      SELECT false, 0, v_user_seeds, 'Invalid plot ID — must be 0 to 23'::text;
    RETURN;
  END IF;

  -- Find which row this plot belongs to
  SELECT * INTO v_row
  FROM public.farm_rows
  WHERE p_plot_id BETWEEN plot_id_start AND plot_id_end;

  IF NOT FOUND THEN
    RETURN QUERY
      SELECT false, 0, v_user_seeds, 'Plot not assigned to any row'::text;
    RETURN;
  END IF;

  -- Level gate
  IF v_user_level < v_row.unlock_level THEN
    RETURN QUERY SELECT
      false, 0, v_user_seeds,
      format('Requires Level %s (you are Level %s)',
             v_row.unlock_level, v_user_level)::text;
    RETURN;
  END IF;

  -- Already unlocked?
  IF EXISTS (
    SELECT 1 FROM public.user_unlocked_plots
    WHERE user_id = p_user_id AND plot_id = p_plot_id
  ) THEN
    RETURN QUERY
      SELECT false, 0, v_user_seeds, 'Plot already unlocked'::text;
    RETURN;
  END IF;

  -- Seed check (skip for free plots)
  v_cost := v_row.cost_per_plot;
  IF v_cost > 0 AND v_user_seeds < v_cost THEN
    RETURN QUERY SELECT
      false, 0, v_user_seeds,
      format('Not enough seeds. Need %s, have %s', v_cost, v_user_seeds)::text;
    RETURN;
  END IF;

  -- Deduct seeds (only if cost > 0)
  IF v_cost > 0 THEN
    UPDATE public.users
    SET seeds_balance = seeds_balance - v_cost
    WHERE id = p_user_id
    RETURNING seeds_balance INTO v_new_balance;

    INSERT INTO public.seed_transactions (
      user_id, amount, source, reference, balance_after
    ) VALUES (
      p_user_id, -v_cost, 'plot_unlock',
      format('plot_%s', p_plot_id), v_new_balance
    );
  ELSE
    v_new_balance := v_user_seeds;
  END IF;

  -- Record unlock
  INSERT INTO public.user_unlocked_plots (user_id, plot_id)
  VALUES (p_user_id, p_plot_id);

  RETURN QUERY SELECT
    true, v_cost, v_new_balance,
    format('Plot %s unlocked! 🌱', p_plot_id)::text;
END;
$$;


-- ============================================================================
-- VERIFY (run manually after applying):
--
-- New functions exist:
-- SELECT proname FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public'
--   AND proname IN ('roll_yield','award_xp','unlock_plot',
--                   'test_harvest_crop','process_postback',
--                   'record_seed_transaction','grant_initial_seeds')
-- ORDER BY proname;
-- Expected: 7 rows
--
-- Dropped function is gone:
-- SELECT proname FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public' AND proname = 'update_user_progression';
-- Expected: 0 rows
--
-- Quick functional test (run in SQL editor with a real user UUID):
-- SELECT * FROM public.roll_yield(1);
-- Expected: one row with yield_multiplier in (0.80, 1.00), tier in ('y1','y2')
--
-- SELECT * FROM public.award_xp('<your-user-uuid>', 100);
-- Expected: new_xp = current + 100, leveled_up = false (unless threshold crossed)
-- ============================================================================
