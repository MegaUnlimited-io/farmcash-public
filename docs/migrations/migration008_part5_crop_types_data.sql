-- ============================================================================
-- MIGRATION008 - Part 5: Crop Types Data
-- Updates: seed_cost, growth_time_hours, unlock_level, p1-p4
-- Source of truth: FarmCash_Game_Economy_Design_v1.md
-- Run after Part 2 (p1-p4 and unlock_level columns must exist).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TOMATO (id=1)
-- Fast crop. 4h grow, 12 seeds.
-- Yield: Speedy 80% (80% prob) | Standard 100% (20% prob)
-- No Bountiful or Golden available on Tomato.
-- EV = (0.80 * 0.80) + (0.20 * 1.00) = 64% + 20% = 84%
-- Harvest formula example: ROUND((12/250) * 0.80, 2) = $0.04
-- ----------------------------------------------------------------------------
UPDATE public.crop_types SET
  seed_cost         = 12,
  growth_time_hours = 4,
  unlock_level      = 1,
  p1                = 0.80,   -- Speedy Harvest   (80% yield)
  p2                = 0.20,   -- Standard Harvest (100% yield)
  p3                = 0.00,   -- Bountiful        — NOT available on Tomato
  p4                = 0.00    -- Golden           — NOT available on Tomato
WHERE name = 'tomato';

-- ----------------------------------------------------------------------------
-- EGGPLANT (id=2)
-- Mid crop. 24h grow, 24 seeds. Unlocks at Level 4.
-- Yield: Speedy 42% | Standard 56% | Bountiful 2%
-- EV = (0.42*0.80) + (0.56*1.00) + (0.02*1.25) = 33.6 + 56 + 2.5 = 92.1%
-- ----------------------------------------------------------------------------
UPDATE public.crop_types SET
  seed_cost         = 24,
  growth_time_hours = 24,
  unlock_level      = 4,
  p1                = 0.42,   -- Speedy Harvest   (80% yield)
  p2                = 0.56,   -- Standard Harvest (100% yield)
  p3                = 0.02,   -- Bountiful Harvest (125% yield)
  p4                = 0.00    -- Golden           — NOT available on Eggplant
WHERE name = 'eggplant';

-- ----------------------------------------------------------------------------
-- CORN (id=3)
-- Long crop. 7 days (168h), 100 seeds. Unlocks at Level 6.
-- Yield: Standard 97% | Bountiful 3%
-- EV = (0.97*1.00) + (0.03*1.25) = 97 + 3.75 = 100.75%
-- First crop with EV > 100%.
-- ----------------------------------------------------------------------------
UPDATE public.crop_types SET
  seed_cost         = 100,
  growth_time_hours = 168,
  unlock_level      = 6,
  p1                = 0.00,   -- Speedy           — NOT available on Corn
  p2                = 0.97,   -- Standard Harvest (100% yield)
  p3                = 0.03,   -- Bountiful Harvest (125% yield)
  p4                = 0.00    -- Golden           — NOT available on Corn
WHERE name = 'corn';

-- ----------------------------------------------------------------------------
-- GOLDEN MELON (id=4)
-- Premium crop. 21 days (504h), 200 seeds. Unlocks at Level 8.
-- Yield: Standard 93% | Bountiful 4% | Golden 3%
-- EV = (0.93*1.00) + (0.04*1.25) + (0.03*2.00) = 93 + 5 + 6 = 104%
-- ONLY crop with Golden Harvest (Y4/200%) available — the chase mechanic.
-- 3% golden chance × 200% yield = the reason endgame players chase melons.
-- ----------------------------------------------------------------------------
UPDATE public.crop_types SET
  seed_cost         = 200,
  growth_time_hours = 504,
  unlock_level      = 8,
  p1                = 0.00,   -- Speedy           — NOT available on Golden Melon
  p2                = 0.93,   -- Standard Harvest (100% yield)
  p3                = 0.04,   -- Bountiful Harvest (125% yield)
  p4                = 0.03    -- Golden Harvest   — EXCLUSIVE to Golden Melon
WHERE name = 'golden_melon';

-- ----------------------------------------------------------------------------
-- Safety validation: probabilities must sum to 1.00 for each crop.
-- Postgres won't enforce this automatically — we validate here.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_crop RECORD;
  v_sum  numeric;
BEGIN
  FOR v_crop IN
    SELECT id, name, p1, p2, p3, p4
    FROM public.crop_types
    WHERE active = true
  LOOP
    v_sum := v_crop.p1 + v_crop.p2 + v_crop.p3 + v_crop.p4;
    IF ABS(v_sum - 1.0) > 0.001 THEN
      RAISE EXCEPTION
        'Crop "%" (id=%) probabilities sum to % — must equal 1.0',
        v_crop.name, v_crop.id, v_sum;
    END IF;
  END LOOP;
  RAISE NOTICE 'All crop probability tables validated OK ✓';
END $$;

-- ============================================================================
-- VERIFY (run manually after applying):
--
-- SELECT name, seed_cost, growth_time_hours, unlock_level,
--        p1, p2, p3, p4,
--        ROUND(p1+p2+p3+p4, 3) AS prob_sum,
--        ROUND((p1*0.80 + p2*1.00 + p3*1.25 + p4*2.00) * 100, 1) AS ev_pct
-- FROM public.crop_types ORDER BY id;
--
-- Expected:
--   tomato       | 12  | 4   | 1 | 0.80 | 0.20 | 0.00 | 0.00 | 1.000 | 84.0
--   eggplant     | 24  | 24  | 4 | 0.42 | 0.56 | 0.02 | 0.00 | 1.000 | 92.1
--   corn         | 100 | 168 | 6 | 0.00 | 0.97 | 0.03 | 0.00 | 1.000 | 100.8
--   golden_melon | 200 | 504 | 8 | 0.00 | 0.93 | 0.04 | 0.03 | 1.000 | 104.0
-- ============================================================================
