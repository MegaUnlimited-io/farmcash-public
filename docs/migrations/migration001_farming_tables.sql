l-- FarmCash Supabase Database Schema v1.0
-- Core farming mechanics for MVP
-- Created: January 5, 2026

-- =====================================================
-- CROP TYPES (Master Data)
-- =====================================================

CREATE TABLE crop_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE, -- 'tomato', 'eggplant', 'corn', 'golden_melon'
    display_name VARCHAR(100) NOT NULL, -- 'Golden Melon', 'Tomato', etc.
    growth_time_hours INTEGER NOT NULL, -- 4, 24, 168, 720 (4h, 1d, 7d, 30d)
    base_yield_percentage INTEGER NOT NULL, -- 75, 100, 115, 130
    seed_cost INTEGER NOT NULL, -- 25, 50, 100, 200 seeds required to plant
    emoji VARCHAR(10), -- '🍅', '🍆', '🌽', '🍈'
    unlock_level INTEGER DEFAULT 1, -- User level required to unlock crop
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert initial crop types with seed costs
INSERT INTO crop_types (name, display_name, growth_time_hours, base_yield_percentage, seed_cost, emoji, unlock_level) VALUES
('tomato', 'Tomato', 4, 75, 25, '🍅', 1),
('eggplant', 'Eggplant', 24, 100, 50, '🍆', 1),
('corn', 'Corn', 168, 115, 100, '🌽', 1), -- 7 days = 168 hours
('golden_melon', 'Golden Melon', 720, 130, 200, '🍈', 1); -- 30 days = 720 hours

-- =====================================================
-- USER FARMS (One per user)
-- =====================================================

CREATE TABLE user_farms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    farm_name VARCHAR(100) DEFAULT 'My Farm',
    farm_level INTEGER DEFAULT 1,
    max_plots INTEGER DEFAULT 15, -- Starting with 15 plots, expandable later
    total_harvests INTEGER DEFAULT 0,
    seeds_balance INTEGER DEFAULT 100, -- Configurable starting seeds
    cash_balance DECIMAL(10,2) DEFAULT 0.00, -- Accumulated cash from harvests
    experience_points INTEGER DEFAULT 0, -- Future progression system
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id) -- One farm per user
);

-- =====================================================
-- CROPS (Active crops growing on farms)
-- =====================================================

CREATE TABLE crops (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_farm_id UUID NOT NULL REFERENCES user_farms(id) ON DELETE CASCADE,
    crop_type_id INTEGER NOT NULL REFERENCES crop_types(id),
    plot_position INTEGER NOT NULL, -- 0-14 for 15 plots (0-based indexing)
    
    -- Growth tracking
    planted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    harvest_ready_at TIMESTAMP WITH TIME ZONE NOT NULL, -- planted_at + growth_time
    harvested_at TIMESTAMP WITH TIME ZONE NULL, -- NULL = still growing
    
    -- Economic data
    seeds_invested INTEGER NOT NULL, -- Seeds used to plant (copied from crop_types.seed_cost)
    yield_multiplier DECIMAL(3,2) DEFAULT 1.0, -- 1.0 = normal, >1.0 = bonuses (future)
    final_cash_value DECIMAL(10,2) NULL, -- Calculated at harvest
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'growing', -- 'growing', 'ready', 'harvested'
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CHECK (plot_position >= 0 AND plot_position < 50), -- Allow future expansion
    CHECK (status IN ('growing', 'ready', 'harvested')),
    CHECK (seeds_invested > 0),
    CHECK (yield_multiplier > 0)
);

-- Create unique index for active crops (one crop per plot when growing)
CREATE UNIQUE INDEX idx_crops_active_plot 
ON crops (user_farm_id, plot_position) 
WHERE harvested_at IS NULL;

-- =====================================================
-- HARVEST HISTORY (Analytics & User Progress)
-- =====================================================

CREATE TABLE harvest_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_farm_id UUID NOT NULL REFERENCES user_farms(id) ON DELETE CASCADE,
    crop_type_id INTEGER NOT NULL REFERENCES crop_types(id),
    
    -- Harvest details
    seeds_invested INTEGER NOT NULL,
    cash_earned DECIMAL(10,2) NOT NULL,
    growth_time_actual INTERVAL NOT NULL, -- Actual time from plant to harvest
    yield_percentage INTEGER NOT NULL, -- Final yield after any bonuses
    plot_position INTEGER NOT NULL, -- Which plot was harvested
    
    -- Context for analytics
    harvested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_level_at_harvest INTEGER, -- User's level when harvest occurred
    total_harvests_before INTEGER, -- User's harvest count before this one
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- APP CONFIG (Admin-configurable values)
-- =====================================================

CREATE TABLE app_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(50) NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    value_type VARCHAR(20) DEFAULT 'string', -- 'string', 'integer', 'decimal', 'boolean'
    description TEXT,
    updated_by UUID REFERENCES auth.users(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert configurable economics values
INSERT INTO app_config (config_key, config_value, value_type, description) VALUES
('demo_seeds', '100', 'integer', 'Starting seeds for new users (FTUE)'),
('email_bonus_seeds', '50', 'integer', 'Bonus seeds for email verification'),
('survey_bonus_seeds', '50', 'integer', 'Bonus seeds for completing survey'),
('phone_bonus_seeds', '100', 'integer', 'Bonus seeds for phone verification'),
('min_withdrawal_amount', '10.00', 'decimal', 'Minimum cash withdrawal amount'),
('seeds_to_dollar_rate', '0.01', 'decimal', 'Base conversion rate: seeds to USD'),
('max_plots_default', '15', 'integer', 'Default maximum plots per farm');

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all user-specific tables
ALTER TABLE user_farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE crops ENABLE ROW LEVEL SECURITY;
ALTER TABLE harvest_history ENABLE ROW LEVEL SECURITY;

-- User Farms: Users can only access their own farm
CREATE POLICY "Users can manage own farm" ON user_farms
    FOR ALL USING (auth.uid() = user_id);

-- Crops: Users can only access crops on their farm
CREATE POLICY "Users can manage crops on own farm" ON crops
    FOR ALL USING (
        user_farm_id IN (
            SELECT id FROM user_farms WHERE user_id = auth.uid()
        )
    );

-- Harvest History: Users can only view their own history
CREATE POLICY "Users can view own harvest history" ON harvest_history
    FOR SELECT USING (
        user_farm_id IN (
            SELECT id FROM user_farms WHERE user_id = auth.uid()
        )
    );

-- App Config: Public read access for all users
CREATE POLICY "Everyone can read app config" ON app_config
    FOR SELECT USING (TRUE);

-- Crop Types: Public read access (master data)
ALTER TABLE crop_types ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Everyone can read crop types" ON crop_types
    FOR SELECT USING (TRUE);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- User farm lookup
CREATE INDEX idx_user_farms_user_id ON user_farms(user_id);

-- Crop queries
CREATE INDEX idx_crops_user_farm ON crops(user_farm_id);
CREATE INDEX idx_crops_status ON crops(status);
CREATE INDEX idx_crops_harvest_ready ON crops(harvest_ready_at) WHERE status = 'ready';
CREATE INDEX idx_crops_plot_position ON crops(user_farm_id, plot_position);

-- Harvest history analytics
CREATE INDEX idx_harvest_history_user_farm ON harvest_history(user_farm_id);
CREATE INDEX idx_harvest_history_date ON harvest_history(harvested_at);
CREATE INDEX idx_harvest_history_crop_type ON harvest_history(crop_type_id);

-- App config lookup
CREATE INDEX idx_app_config_key ON app_config(config_key);

-- =====================================================
-- FUNCTIONS & TRIGGERS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at triggers
CREATE TRIGGER update_crop_types_updated_at BEFORE UPDATE ON crop_types
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_farms_updated_at BEFORE UPDATE ON user_farms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_crops_updated_at BEFORE UPDATE ON crops
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate harvest ready time
CREATE OR REPLACE FUNCTION set_harvest_ready_time()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate harvest ready time based on crop type
    SELECT 
        NEW.planted_at + (ct.growth_time_hours * INTERVAL '1 hour')
    INTO NEW.harvest_ready_at
    FROM crop_types ct 
    WHERE ct.id = NEW.crop_type_id;
    
    -- Copy seed cost from crop type (for historical record)
    IF NEW.seeds_invested IS NULL THEN
        SELECT ct.seed_cost INTO NEW.seeds_invested
        FROM crop_types ct 
        WHERE ct.id = NEW.crop_type_id;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-calculate harvest ready time and seed cost
CREATE TRIGGER set_crop_harvest_time BEFORE INSERT ON crops
    FOR EACH ROW EXECUTE FUNCTION set_harvest_ready_time();

-- Function to update crop status when harvest_ready_at passes
CREATE OR REPLACE FUNCTION update_crop_status()
RETURNS VOID AS $$
BEGIN
    UPDATE crops 
    SET status = 'ready'
    WHERE harvest_ready_at <= NOW() 
    AND status = 'growing';
END;
$$ language 'plpgsql';

-- =====================================================
-- HELPER VIEWS FOR COMMON QUERIES
-- =====================================================

-- View for active crops with crop type details
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

-- View for farm overview with statistics
CREATE VIEW farm_overview AS
SELECT 
    uf.id as farm_id,
    uf.user_id,
    uf.farm_name,
    uf.farm_level,
    uf.seeds_balance,
    uf.cash_balance,
    uf.total_harvests,
    uf.max_plots,
    COUNT(c.id) as active_crops,
    COUNT(CASE WHEN c.status = 'ready' OR c.harvest_ready_at <= NOW() THEN 1 END) as crops_ready_to_harvest
FROM user_farms uf
LEFT JOIN crops c ON uf.id = c.user_farm_id AND c.harvested_at IS NULL
GROUP BY uf.id, uf.user_id, uf.farm_name, uf.farm_level, uf.seeds_balance, 
         uf.cash_balance, uf.total_harvests, uf.max_plots;

-- =====================================================
-- INITIAL SETUP FUNCTIONS
-- =====================================================

-- Function to create initial farm for new users
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
    
    -- Create farm with starting seeds
    INSERT INTO user_farms (user_id, seeds_balance)
    VALUES (user_id_param, COALESCE(starting_seeds, 100))
    RETURNING id INTO farm_id;
    
    RETURN farm_id;
END;
$$ language 'plpgsql' SECURITY DEFINER;

-- =====================================================
-- VALIDATION QUERIES (Run to test schema)
-- =====================================================

-- Test: Get all crop types with costs
-- SELECT name, display_name, growth_time_hours, base_yield_percentage, seed_cost, emoji FROM crop_types ORDER BY seed_cost;

-- Test: Create a test farm and plant crops
-- SELECT create_initial_farm_for_user('test-user-uuid');
-- SELECT * FROM farm_overview WHERE user_id = 'test-user-uuid';

-- Test: Plant a tomato crop
-- INSERT INTO crops (user_farm_id, crop_type_id, plot_position) 
-- VALUES ('farm-uuid', 1, 0);

-- Test: View active crops
-- SELECT * FROM active_crops_with_details WHERE user_farm_id = 'farm-uuid';