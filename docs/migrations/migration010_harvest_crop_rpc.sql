-- =====================================================
-- migration010_harvest_crop_rpc.sql
-- Purpose: production harvest RPC used by farm UI
-- =====================================================

CREATE OR REPLACE FUNCTION public.harvest_crop(p_crop_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id        uuid;
  v_user_id          uuid;
  v_seeds_invested   integer;
  v_crop_type_id     integer;
  v_crop_name        text;
  v_plot_position    integer;
  v_base_rate        numeric;
  v_yield            record;
  v_cash_amount      numeric;
  v_new_cash_balance numeric;
  v_harvest_ready_at timestamptz;
  v_harvested_at     timestamptz;
BEGIN
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT
    uf.user_id,
    c.seeds_invested,
    c.crop_type_id,
    ct.name,
    c.plot_position,
    c.harvest_ready_at,
    c.harvested_at
  INTO
    v_user_id,
    v_seeds_invested,
    v_crop_type_id,
    v_crop_name,
    v_plot_position,
    v_harvest_ready_at,
    v_harvested_at
  FROM public.crops c
  JOIN public.user_farms uf ON uf.id = c.user_farm_id
  JOIN public.crop_types ct ON ct.id = c.crop_type_id
  WHERE c.id = p_crop_id
    AND uf.user_id = v_caller_id
  FOR UPDATE OF c;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Crop not found';
  END IF;

  IF v_harvested_at IS NOT NULL THEN
    RAISE EXCEPTION 'Crop already harvested';
  END IF;

  IF v_harvest_ready_at > NOW() THEN
    RAISE EXCEPTION 'Crop not ready';
  END IF;

  SELECT config_value::numeric
  INTO v_base_rate
  FROM public.app_config
  WHERE config_key = 'base_rate';

  v_base_rate := COALESCE(v_base_rate, 250);

  SELECT * INTO v_yield
  FROM public.roll_yield(v_crop_type_id);

  v_cash_amount := ROUND(
    (v_seeds_invested::numeric / v_base_rate) * v_yield.yield_multiplier,
    2
  );

  UPDATE public.users
  SET cash_balance = cash_balance + v_cash_amount
  WHERE id = v_user_id
  RETURNING cash_balance INTO v_new_cash_balance;

  UPDATE public.crops
  SET
    harvested_at = NOW(),
    status = 'harvested',
    final_cash_value = v_cash_amount,
    yield_multiplier = v_yield.yield_multiplier
  WHERE id = p_crop_id;

  INSERT INTO public.harvest_history (
    user_farm_id,
    crop_type_id,
    seeds_invested,
    cash_earned,
    growth_time_actual,
    yield_percentage,
    plot_position,
    harvested_at
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
    'success', true,
    'crop_id', p_crop_id,
    'plot_position', v_plot_position,
    'crop_type_id', v_crop_type_id,
    'crop_name', v_crop_name,
    'seeds_invested', v_seeds_invested,
    'cash_earned', v_cash_amount,
    'new_cash_balance', v_new_cash_balance,
    'yield_tier', v_yield.tier,
    'yield_label', v_yield.tier_label,
    'yield_multiplier', v_yield.yield_multiplier
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.harvest_crop(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.harvest_crop(uuid) TO service_role;
