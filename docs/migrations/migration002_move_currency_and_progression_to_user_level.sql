-- MIGRATION002_Move_Currency_And_Progression_To_User_Level.sql
-- Move seeds_balance, cash_balance, user_level, total_harvests, experience_points from user_farms to public.users
-- Remove farm_level entirely (no current use case)
-- Created: January 5, 2026
-- Reason: Currency and progression should be user-level, not farm-level for better architecture

-- =====================================================
-- STEP 1: Add currency and progression columns to public.users
-- =====================================================

-- Add currency balances to user table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS seeds_balance INTEGER DEFAULT 100;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS cash_balance DECIMAL(10,2) DEFAULT 0.00;

-- Add user progression to user table (these are user-level, not farm-level)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS user_level INTEGER DEFAULT 1;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS total_harvests INTEGER DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS experience_points INTEGER DEFAULT 0;

-- =====================================================
-- STEP 2: Drop dependent views first
-- =====================================================

-- Drop views that depend on columns we're about to remove
DROP VIEW IF EXISTS farm_overview;
DROP VIEW IF EXISTS active_crops_with_details;

-- =====================================================
-- STEP 3: Migrate existing data (if any exists)
-- =====================================================

-- Migrate balances and progression from user_farms to public.users
UPDATE public.users 
SET 
    seeds_balance = COALESCE(uf.seeds_balance, 100),
    cash_balance = COALESCE(uf.cash_balance, 0.00),
    user_level = COALESCE(uf.farm_level, 1),  -- Migrate farm_level to user_level
    total_harvests = COALESCE(uf.total_harvests, 0),
    experience_points = COALESCE(uf.experience_points, 0)
FROM user_farms uf 
WHERE public.users.id = uf.user_id;

-- =====================================================
-- STEP 4: Remove columns from user_farms
-- =====================================================

-- Remove currency and ALL progression from farm table
ALTER TABLE user_farms DROP COLUMN IF EXISTS seeds_balance;
ALTER TABLE user_farms DROP COLUMN IF EXISTS cash_balance;
ALTER TABLE user_farms DROP COLUMN IF EXISTS farm_level;  -- Remove entirely
ALTER TABLE user_farms DROP COLUMN IF EXISTS total_harvests;
ALTER TABLE user_farms DROP COLUMN IF EXISTS experience_points;

-- =====================================================
-- STEP 5: Update functions to use user-level balances/progression
-- =====================================================

-- Update create_initial_farm_for_user function
CREATE OR REPLACE FUNCTION create_initial_farm_for_user(user_id_param UUID)
RETURNS UUID AS $$
DECLARE
    farm_id UUID;
    starting_seeds INTEGER;
BEGIN
    -- Get configurable starting seeds
    SELECT config_value::INTEGER INTO starting_seeds 
    FROM app_config 
    WHERE config_key = 'demo_seeds';
    
    -- Set user's initial seeds balance (if not already set)
    UPDATE public.users 
    SET seeds_balance = COALESCE(starting_seeds, 100)
    WHERE id = user_id_param 
    AND (seeds_balance IS NULL OR seeds_balance = 0);
    
    -- Create farm (only farm-specific data)
    INSERT INTO user_farms (user_id, farm_name, max_plots)
    VALUES (user_id_param, 'My Farm', 15)
    RETURNING id INTO farm_id;
    
    RETURN farm_id;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- =====================================================
-- STEP 6: Recreate views with user-level balances/progression
-- =====================================================

-- Recreate farm_overview view with user balances and progression
DROP VIEW IF EXISTS farm_overview;

CREATE VIEW farm_overview AS
SELECT 
    uf.id as farm_id,
    uf.user_id,
    uf.farm_name,
    uf.max_plots,
    -- Get balances and progression from user table
    u.seeds_balance,
    u.cash_balance,
    u.user_level,
    u.total_harvests,
    u.experience_points,
    -- Farm-specific stats
    COUNT(c.id) as active_crops,
    COUNT(CASE WHEN c.status = 'ready' OR c.harvest_ready_at <= NOW() THEN 1 END) as crops_ready_to_harvest
FROM user_farms uf
JOIN public.users u ON uf.user_id = u.id
LEFT JOIN crops c ON uf.id = c.user_farm_id AND c.harvested_at IS NULL
GROUP BY uf.id, uf.user_id, uf.farm_name, uf.max_plots,
         u.seeds_balance, u.cash_balance, u.user_level, u.total_harvests, u.experience_points;

-- Recreate active_crops_with_details view (unchanged)
CREATE VIEW active_crops_with_details AS
SELECT 
    c.id,
    c.user_farm_id,
    c.plot_position,
    c.planted_at,
    c.harvest_ready_at,
    c.status,
    c.seeds_invested,
    c.yield_multiplier,
    ct.name as crop_name,
    ct.display_name,
    ct.emoji,
    ct.base_yield_percentage,
    CASE 
        WHEN c.harvest_ready_at <= NOW() THEN 'ready'
        ELSE 'growing'
    END as current_status,
    EXTRACT(EPOCH FROM (c.harvest_ready_at - NOW())) as seconds_until_ready
FROM crops c
JOIN crop_types ct ON c.crop_type_id = ct.id
WHERE c.harvested_at IS NULL;

-- =====================================================
-- STEP 7: Update RLS policies for public.users
-- =====================================================

-- Enable RLS on public.users if not already enabled
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Allow users to read/update their own profile
CREATE POLICY "Users can view own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id);

-- =====================================================
-- STEP 8: Add helpful functions for currency and progression operations
-- =====================================================

-- Function to get user's current balances
CREATE OR REPLACE FUNCTION get_user_balances(user_id_param UUID)
RETURNS TABLE(seeds_balance INTEGER, cash_balance DECIMAL(10,2)) AS $$
BEGIN
    RETURN QUERY
    SELECT u.seeds_balance, u.cash_balance
    FROM public.users u
    WHERE u.id = user_id_param;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Function to update user seeds balance
CREATE OR REPLACE FUNCTION update_user_seeds(user_id_param UUID, seeds_change INTEGER)
RETURNS INTEGER AS $$
DECLARE
    new_balance INTEGER;
BEGIN
    UPDATE public.users
    SET seeds_balance = seeds_balance + seeds_change
    WHERE id = user_id_param
    RETURNING seeds_balance INTO new_balance;
    
    RETURN new_balance;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Function to update user cash balance
CREATE OR REPLACE FUNCTION update_user_cash(user_id_param UUID, cash_change DECIMAL(10,2))
RETURNS DECIMAL(10,2) AS $$
DECLARE
    new_balance DECIMAL(10,2);
BEGIN
    UPDATE public.users
    SET cash_balance = cash_balance + cash_change
    WHERE id = user_id_param
    RETURNING cash_balance INTO new_balance;
    
    RETURN new_balance;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- Function to update user level and experience
CREATE OR REPLACE FUNCTION update_user_progression(user_id_param UUID, xp_change INTEGER)
RETURNS TABLE(new_level INTEGER, new_xp INTEGER) AS $$
DECLARE
    current_level INTEGER;
    current_xp INTEGER;
    calculated_level INTEGER;
BEGIN
    -- Get current values
    SELECT user_level, experience_points INTO current_level, current_xp
    FROM public.users WHERE id = user_id_param;
    
    -- Add XP
    current_xp := current_xp + xp_change;
    
    -- Simple level calculation (can be enhanced later)
    -- Level 2 at 100 XP, Level 3 at 300 XP, Level 4 at 600 XP, etc.
    calculated_level := 1 + FLOOR(SQRT(current_xp / 50));
    
    -- Update user
    UPDATE public.users
    SET 
        experience_points = current_xp,
        user_level = GREATEST(current_level, calculated_level) -- Never decrease level
    WHERE id = user_id_param
    RETURNING user_level, experience_points INTO new_level, new_xp;
    
    RETURN QUERY SELECT new_level, new_xp;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- =====================================================
-- VALIDATION QUERIES
-- =====================================================

-- Test: Check user balances and progression
-- SELECT id, email, seeds_balance, cash_balance, user_level, total_harvests, experience_points FROM public.users LIMIT 5;

-- Test: Check updated farm overview
-- SELECT * FROM farm_overview LIMIT 5;

-- Test: Create farm for real user
-- SELECT create_initial_farm_for_user((SELECT id FROM auth.users LIMIT 1));

-- Test: Update user progression
-- SELECT * FROM update_user_progression((SELECT id FROM auth.users LIMIT 1), 150);

-- =====================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON COLUMN public.users.seeds_balance IS 'User virtual currency for planting crops';
COMMENT ON COLUMN public.users.cash_balance IS 'User real money balance from harvested crops';
COMMENT ON COLUMN public.users.user_level IS 'User progression level (unlocks crops and features)';
COMMENT ON COLUMN public.users.total_harvests IS 'Lifetime harvest count across all farms';
COMMENT ON COLUMN public.users.experience_points IS 'XP for progression - persists through farm resets';

COMMENT ON TABLE user_farms IS 'Individual farm instances owned by users (farm-specific data only)';
COMMENT ON COLUMN user_farms.max_plots IS 'Maximum plots available on this specific farm';
COMMENT ON COLUMN user_farms.farm_name IS 'User-customizable name for this farm';