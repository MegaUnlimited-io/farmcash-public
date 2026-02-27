-- ============================================================================
-- MIGRATION008 - Part 2: Column Changes
-- Modifies: public.users, public.seed_transactions, public.crop_types
-- Fixes:    active_crops_with_details view (depends on base_yield_percentage)
-- Run after Part 1.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. PUBLIC.USERS
-- Rename ApparenceKit columns to FarmCash canonical names.
-- We have 0 real users — no deprecation needed, rename directly.
-- Add: watering_unlocked, sprouting_seeds_balance
-- ----------------------------------------------------------------------------

-- Rename legacy ApparenceKit columns
ALTER TABLE public.users RENAME COLUMN user_level          TO level;
ALTER TABLE public.users RENAME COLUMN experience_points   TO xp;

-- New FarmCash columns
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS watering_unlocked        boolean  NOT NULL DEFAULT false;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS sprouting_seeds_balance  integer  NOT NULL DEFAULT 0;
-- sprouting_seeds_balance: seeds awarded but pending advertiser confirmation.
-- Populated when OCG receives postback with status='pending'.
-- Moves to seeds_balance when status flips to 'completed'.
-- TODO: Wire up in Week 3 when OCG pending/confirmed states are built.

-- ----------------------------------------------------------------------------
-- 2. SEED_TRANSACTIONS
-- Add xp_granted audit column.
-- Only populated when source = 'offer_completion'.
-- Audit check: SUM(xp_granted) WHERE source='offer_completion' = users.xp
-- ----------------------------------------------------------------------------
ALTER TABLE public.seed_transactions
  ADD COLUMN IF NOT EXISTS xp_granted integer NOT NULL DEFAULT 0;

-- ----------------------------------------------------------------------------
-- 3. CROP_TYPES
-- Add: unlock_level, p1-p4 (yield probabilities per crop)
-- Remove: base_yield_percentage (replaced by RYR system)
--
-- base_yield_percentage is referenced by active_crops_with_details view —
-- drop the view first, drop the column, then recreate the view correctly.
-- ----------------------------------------------------------------------------

-- Drop dependent view first
DROP VIEW IF EXISTS public.active_crops_with_details;

ALTER TABLE public.crop_types
  ADD COLUMN IF NOT EXISTS unlock_level integer NOT NULL DEFAULT 1;

ALTER TABLE public.crop_types ADD COLUMN IF NOT EXISTS p1 numeric NOT NULL DEFAULT 0;
ALTER TABLE public.crop_types ADD COLUMN IF NOT EXISTS p2 numeric NOT NULL DEFAULT 0;
ALTER TABLE public.crop_types ADD COLUMN IF NOT EXISTS p3 numeric NOT NULL DEFAULT 0;
ALTER TABLE public.crop_types ADD COLUMN IF NOT EXISTS p4 numeric NOT NULL DEFAULT 0;

-- Drop old fixed yield column (view is gone, safe to drop now)
ALTER TABLE public.crop_types DROP COLUMN IF EXISTS base_yield_percentage;

-- ----------------------------------------------------------------------------
-- Recreate active_crops_with_details
-- Changes from original:
--   REMOVED: base_yield_percentage (column no longer exists)
--   ADDED:   p1, p2, p3, p4 (yield probability table per crop)
--   ADDED:   unlock_level (useful for UI to show lock state)
--   KEPT:    dynamic status CASE (growing/ready) — replaces stored status
--            which can go stale. This view is always accurate.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.active_crops_with_details AS
SELECT
  c.id,
  c.user_farm_id,
  c.crop_type_id,
  c.plot_position,
  c.planted_at,
  c.harvest_ready_at,
  c.harvested_at,
  c.seeds_invested,
  c.yield_multiplier::double precision AS yield_multiplier,
  c.final_cash_value,
  CASE
    WHEN c.harvest_ready_at <= now() THEN 'ready'
    ELSE 'growing'
  END::character varying(20) AS status,
  ct.name         AS crop_name,
  ct.display_name,
  ct.emoji,
  ct.growth_time_hours,
  ct.unlock_level,
  ct.p1,
  ct.p2,
  ct.p3,
  ct.p4
FROM crops c
JOIN crop_types ct ON ct.id = c.crop_type_id
WHERE c.harvested_at IS NULL;

-- ============================================================================
-- VERIFY (run manually after applying):
--
-- Renamed columns exist on users:
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'users'
--   AND column_name IN ('level', 'xp', 'watering_unlocked', 'sprouting_seeds_balance')
-- ORDER BY column_name;
-- Expected: 4 rows
--
-- Old column names are gone:
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'users'
--   AND column_name IN ('user_level', 'experience_points');
-- Expected: 0 rows
--
-- New crop_types columns, old one gone:
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'crop_types'
--   AND column_name IN ('unlock_level','p1','p2','p3','p4','base_yield_percentage')
-- ORDER BY column_name;
-- Expected: 5 rows (p1,p2,p3,p4,unlock_level) — base_yield_percentage NOT present
--
-- View recreated correctly:
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'active_crops_with_details'
-- ORDER BY column_name;
-- Expected: p1,p2,p3,p4,unlock_level present; base_yield_percentage absent
-- ============================================================================