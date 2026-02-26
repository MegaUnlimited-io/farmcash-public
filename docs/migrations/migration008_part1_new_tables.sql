-- ============================================================================
-- MIGRATION008 - Part 1: New Tables
-- Creates: levels, farm_rows, user_unlocked_plots
-- Run FIRST. Pure CREATE statements — nothing destructive.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. FARM ROWS (created before levels — levels has FK into farm_rows)
-- Static reference table: defines physical row layout and unlock costs.
-- Each row = 3 plots. Row numbering is 1-indexed.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.farm_rows (
  row_number     integer   PRIMARY KEY,
  plot_id_start  integer   NOT NULL,
  plot_id_end    integer   NOT NULL,
  unlock_level   integer   NOT NULL,
  cost_per_plot  integer   NOT NULL DEFAULT 0,
  CONSTRAINT farm_rows_plot_range CHECK (plot_id_end >= plot_id_start),
  CONSTRAINT farm_rows_cost_check  CHECK (cost_per_plot >= 0)
);

-- ----------------------------------------------------------------------------
-- 2. LEVELS TABLE
-- Single source of truth for all progression logic:
-- XP thresholds, crop unlocks, row soft-unlocks, watering unlock.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.levels (
  level             integer  PRIMARY KEY,
  xp_threshold      integer  NOT NULL,           -- Cumulative XP to reach this level
  xp_to_next        integer  NULL,               -- XP needed to reach next level (NULL at max)
  crop_unlock_id    integer  NULL REFERENCES public.crop_types(id),
  row_unlock        integer  NULL REFERENCES public.farm_rows(row_number),
  unlocks_watering  boolean  NOT NULL DEFAULT false,
  label             text     NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_levels_xp_threshold ON public.levels(xp_threshold);

-- ----------------------------------------------------------------------------
-- 3. USER UNLOCKED PLOTS
-- Per-user record of which plots have been purchased/granted.
-- Plots 0-5 auto-inserted at signup via create_initial_farm_for_user().
-- plot_id range: 0-23 (max 24 plots across 8 rows of 3)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_unlocked_plots (
  user_id     uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  plot_id     integer     NOT NULL CHECK (plot_id >= 0 AND plot_id <= 23),
  unlocked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, plot_id)
);

CREATE INDEX IF NOT EXISTS idx_user_unlocked_plots_user
  ON public.user_unlocked_plots(user_id);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
ALTER TABLE public.farm_rows           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.levels              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_unlocked_plots ENABLE ROW LEVEL SECURITY;

-- levels + farm_rows: read-only reference data for all authenticated users
CREATE POLICY "levels_read_authenticated" ON public.levels
  FOR SELECT TO authenticated USING (true);

CREATE POLICY "farm_rows_read_authenticated" ON public.farm_rows
  FOR SELECT TO authenticated USING (true);

-- user_unlocked_plots: users see only their own rows
CREATE POLICY "user_unlocked_plots_own" ON public.user_unlocked_plots
  FOR ALL TO authenticated USING (auth.uid() = user_id);

-- ============================================================================
-- VERIFY (run manually after applying):
-- SELECT table_name
-- FROM information_schema.tables
-- WHERE table_schema = 'public'
--   AND table_name IN ('levels', 'farm_rows', 'user_unlocked_plots')
-- ORDER BY table_name;
-- Expected: 3 rows
-- ============================================================================
