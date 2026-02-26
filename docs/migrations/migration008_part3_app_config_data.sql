-- ============================================================================
-- MIGRATION008 - Part 3: App Config Data
-- Adds new economy keys, removes deprecated keys.
-- Safe to re-run (uses ON CONFLICT upsert).
-- Run after Part 2.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Remove deprecated keys
-- max_plots_default  — replaced by farm_rows + user_unlocked_plots system
-- seeds_to_dollar_rate — replaced by base_rate + payout_rate
-- ----------------------------------------------------------------------------
DELETE FROM public.app_config WHERE config_key = 'max_plots_default';
DELETE FROM public.app_config WHERE config_key = 'seeds_to_dollar_rate';

-- ----------------------------------------------------------------------------
-- Upsert new economy config keys
-- All values are configurable here without code changes.
-- payout_rate is entered manually (= base_rate * (1 - first_margin_take))
-- Current values: 250 * (1 - 0.45) = 137.5 → rounded to 138
-- ----------------------------------------------------------------------------
INSERT INTO public.app_config (config_key, config_value, value_type, description)
VALUES
  ('base_rate',
   '250',
   'integer',
   'Seeds per $1 USD — internal reference rate. Used in harvest calculation: cash = ROUND((seeds / base_rate) * yield_multiplier, 2)'),

  ('payout_rate',
   '138',
   'integer',
   'Seeds per $1 USD delivered to user after FMT. Manually set in offerwall partner dashboards. Formula: base_rate * (1 - first_margin_take) = 250 * 0.55 = 137.5 → 138'),

  ('first_margin_take',
   '0.45',
   'decimal',
   'FMT: fraction of gross offer revenue kept by FarmCash before crediting seeds. 0.45 = 45%. Applied at postback receipt.'),

  ('y1',
   '0.80',
   'decimal',
   'Yield tier 1 multiplier — Speedy Harvest. Used by roll_yield().'),

  ('y2',
   '1.00',
   'decimal',
   'Yield tier 2 multiplier — Standard Harvest. Used by roll_yield().'),

  ('y3',
   '1.25',
   'decimal',
   'Yield tier 3 multiplier — Bountiful Harvest. Used by roll_yield().'),

  ('y4',
   '2.00',
   'decimal',
   'Yield tier 4 multiplier — Golden Harvest. Exclusive to Golden Melon (p4=0 on all other crops). Used by roll_yield().')

ON CONFLICT (config_key) DO UPDATE SET
  config_value = EXCLUDED.config_value,
  description  = EXCLUDED.description;

-- ============================================================================
-- VERIFY (run manually after applying):
--
-- New keys exist:
-- SELECT config_key, config_value
-- FROM public.app_config
-- WHERE config_key IN ('base_rate','payout_rate','first_margin_take','y1','y2','y3','y4')
-- ORDER BY config_key;
-- Expected: 7 rows
--
-- Deprecated keys are gone:
-- SELECT config_key FROM public.app_config
-- WHERE config_key IN ('max_plots_default','seeds_to_dollar_rate');
-- Expected: 0 rows
-- ============================================================================
