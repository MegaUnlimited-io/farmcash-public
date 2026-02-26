-- ============================================================================
-- MIGRATION008 - Part 4: Levels + Farm Rows Seed Data
-- Populates: farm_rows (8 rows), levels (10 levels)
-- Safe to re-run (uses ON CONFLICT upsert).
-- Run after Part 1 (tables must exist).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- FARM ROWS
-- Farm layout: 8 rows × 3 plots = 24 max plots (plot IDs 0–23)
-- Row numbering: 1-indexed
-- Plot IDs: 0-indexed, sequential within each row (left column → right column)
--
-- Visual layout (3 cols × 8 rows):
--   Row 1: [0]  [1]  [2]   — Free, Level 1
--   Row 2: [3]  [4]  [5]   — Free, Level 1
--   Row 3: [6]  [7]  [8]   — Soft-unlocks at Level 2, 100 seeds/plot
--   Row 4: [9]  [10] [11]  — Soft-unlocks at Level 3, 150 seeds/plot
--   Row 5: [12] [13] [14]  — Soft-unlocks at Level 5, 250 seeds/plot
--   Row 6: [15] [16] [17]  — Soft-unlocks at Level 7, 400 seeds/plot
--   Row 7: [18] [19] [20]  — Soft-unlocks at Level 9, 900 seeds/plot
--   Row 8: [21] [22] [23]  — Soft-unlocks at Level 10, 1200 seeds/plot
-- ----------------------------------------------------------------------------
INSERT INTO public.farm_rows (row_number, plot_id_start, plot_id_end, unlock_level, cost_per_plot)
VALUES
  (1,  0,  2,  1,  0),
  (2,  3,  5,  1,  0),
  (3,  6,  8,  2,  100),
  (4,  9,  11, 3,  150),
  (5,  12, 14, 5,  250),
  (6,  15, 17, 7,  400),
  (7,  18, 20, 9,  900),
  (8,  21, 23, 10, 1200)
ON CONFLICT (row_number) DO UPDATE SET
  plot_id_start = EXCLUDED.plot_id_start,
  plot_id_end   = EXCLUDED.plot_id_end,
  unlock_level  = EXCLUDED.unlock_level,
  cost_per_plot = EXCLUDED.cost_per_plot;

-- ----------------------------------------------------------------------------
-- LEVELS
-- crop_unlock_id FK: 1=Tomato, 2=Eggplant, 3=Corn, 4=Golden Melon
-- row_unlock FK: references farm_rows.row_number
--
-- Notes:
-- - Level 1 has row_unlock=NULL: rows 1+2 are granted free at signup
--   via create_initial_farm_for_user() inserting plots 0-5.
-- - Level 3 unlocks watering (watering_unlocked=true on users record).
-- - xp_to_next is NULL at Level 10 (max level).
-- ----------------------------------------------------------------------------
INSERT INTO public.levels
  (level, xp_threshold, xp_to_next, crop_unlock_id, row_unlock, unlocks_watering, label)
VALUES
  -- Level | XP Total | XP to Next | Crop       | Row | Watering | Label
  (1,   0,       500,    1,    NULL, false, 'Seedling'),
  -- Tomato unlocked. Rows 1+2 (plots 0-5) granted free at signup. No row_unlock event needed.

  (2,   500,     500,    NULL, 3,    false, 'Sprout'),
  -- Row 3 soft-unlocks (plots 6-8). User can purchase each for 100 seeds.

  (3,   1000,    1000,   NULL, 4,    true,  'Grower'),
  -- Row 4 soft-unlocks (plots 9-11, 150 seeds/plot). Watering can unlocked.

  (4,   2000,    2000,   2,    NULL, false, 'Farmer'),
  -- Eggplant unlocked. No new row.

  (5,   4000,    4000,   NULL, 5,    false, 'Cultivator'),
  -- Row 5 soft-unlocks (plots 12-14, 250 seeds/plot).

  (6,   8000,    8000,   3,    NULL, false, 'Harvester'),
  -- Corn unlocked. No new row.

  (7,   16000,   16000,  NULL, 6,    false, 'Rancher'),
  -- Row 6 soft-unlocks (plots 15-17, 400 seeds/plot).

  (8,   32000,   32000,  4,    NULL, false, 'Orchardist'),
  -- Golden Melon unlocked. No new row.

  (9,   64000,   64000,  NULL, 7,    false, 'Agronomist'),
  -- Row 7 soft-unlocks (plots 18-20, 900 seeds/plot).

  (10,  128000,  NULL,   NULL, 8,    false, 'Legendary Farmer')
  -- Row 8 soft-unlocks (plots 21-23, 1200 seeds/plot). Max level.

ON CONFLICT (level) DO UPDATE SET
  xp_threshold     = EXCLUDED.xp_threshold,
  xp_to_next       = EXCLUDED.xp_to_next,
  crop_unlock_id   = EXCLUDED.crop_unlock_id,
  row_unlock       = EXCLUDED.row_unlock,
  unlocks_watering = EXCLUDED.unlocks_watering,
  label            = EXCLUDED.label;

-- ============================================================================
-- VERIFY (run manually after applying):
--
-- SELECT level, label, xp_threshold, xp_to_next,
--        crop_unlock_id, row_unlock, unlocks_watering
-- FROM public.levels ORDER BY level;
-- Expected: 10 rows. Level 3 has unlocks_watering=true. Level 10 has xp_to_next=NULL.
--
-- SELECT row_number, plot_id_start, plot_id_end, unlock_level, cost_per_plot
-- FROM public.farm_rows ORDER BY row_number;
-- Expected: 8 rows. Rows 1-2 have cost_per_plot=0.
--
-- Sanity: total plots = SUM(plot_id_end - plot_id_start + 1) = 24
-- SELECT SUM(plot_id_end - plot_id_start + 1) AS total_plots FROM public.farm_rows;
-- Expected: 24
-- ============================================================================
