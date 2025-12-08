-- ============================================================================
-- NUCLEAR OPTION: Clean slate for cross-platform game tracking
-- ============================================================================

-- Step 1: Drop everything related to games (keeps user profiles/auth intact)
DROP TABLE IF EXISTS user_achievements CASCADE;
DROP TABLE IF EXISTS achievements CASCADE;
DROP TABLE IF EXISTS user_games CASCADE;
DROP TABLE IF EXISTS game_titles CASCADE;

-- Step 2: Create clean game_titles (NO platform_id - platform agnostic)
CREATE TABLE game_titles (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  cover_url text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Unique constraint on name (case-insensitive)
CREATE UNIQUE INDEX idx_game_titles_name_unique ON game_titles (LOWER(TRIM(name)));
CREATE INDEX idx_game_titles_metadata ON game_titles USING gin(metadata);

-- Step 3: Create user_games (platform_id here, NOT in game_titles)
CREATE TABLE user_games (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  game_title_id bigint REFERENCES game_titles(id) ON DELETE CASCADE,
  platform_id bigint REFERENCES platforms(id) ON DELETE CASCADE,
  
  -- Universal achievement tracking
  total_trophies int DEFAULT 0,
  earned_trophies int DEFAULT 0,
  completion_percent numeric(5,2) DEFAULT 0,
  has_platinum boolean DEFAULT false,
  
  -- Trophy breakdown (PSN)
  bronze_trophies int DEFAULT 0,
  silver_trophies int DEFAULT 0,
  gold_trophies int DEFAULT 0,
  platinum_trophies int DEFAULT 0,
  
  -- Xbox specific
  xbox_total_achievements int DEFAULT 0,
  xbox_achievements_earned int DEFAULT 0,
  xbox_current_gamerscore int DEFAULT 0,
  xbox_max_gamerscore int DEFAULT 0,
  
  -- Timestamps
  last_played_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  -- One record per user per game per platform
  UNIQUE(user_id, game_title_id, platform_id)
);

CREATE INDEX idx_user_games_user ON user_games(user_id);
CREATE INDEX idx_user_games_game ON user_games(game_title_id);
CREATE INDEX idx_user_games_platform ON user_games(platform_id);
CREATE INDEX idx_user_games_completion ON user_games(completion_percent DESC);

-- Step 4: Create achievements table
CREATE TABLE achievements (
  id bigserial PRIMARY KEY,
  game_title_id bigint REFERENCES game_titles(id) ON DELETE CASCADE,
  platform text NOT NULL CHECK (platform IN ('psn', 'xbox', 'steam')),
  platform_achievement_id text NOT NULL,
  name text NOT NULL,
  description text,
  icon_url text,
  
  -- PSN fields
  psn_trophy_type text CHECK (psn_trophy_type IN ('bronze', 'silver', 'gold', 'platinum', null)),
  
  -- Xbox fields
  xbox_gamerscore int,
  
  -- Universal
  rarity_global numeric(5,2),
  is_dlc boolean DEFAULT false,
  
  created_at timestamptz DEFAULT now(),
  
  UNIQUE(game_title_id, platform, platform_achievement_id)
);

CREATE INDEX idx_achievements_game_platform ON achievements(game_title_id, platform);

-- Step 5: Create user_achievements table
CREATE TABLE user_achievements (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE,
  achievement_id bigint REFERENCES achievements(id) ON DELETE CASCADE,
  earned_at timestamptz NOT NULL,
  created_at timestamptz DEFAULT now(),
  
  UNIQUE(user_id, achievement_id)
);

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id, earned_at DESC);

-- Step 6: Create user_stats table for dashboard
CREATE TABLE user_stats (
  user_id uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  total_games int DEFAULT 0,
  completed_games int DEFAULT 0,
  total_trophies int DEFAULT 0,
  bronze_count int DEFAULT 0,
  silver_count int DEFAULT 0,
  gold_count int DEFAULT 0,
  platinum_count int DEFAULT 0,
  total_gamerscore int DEFAULT 0,
  updated_at timestamptz DEFAULT now()
);

-- Step 7: Create views for dashboard queries
CREATE OR REPLACE VIEW user_statusxp_summary AS
SELECT 
  ug.user_id,
  SUM(
    -- Platinum trophies: 180 XP each
    COALESCE(ug.platinum_trophies, 0) * 180 +
    -- Gold trophies: 90 XP each
    COALESCE(ug.gold_trophies, 0) * 90 +
    -- Silver trophies: 30 XP each
    COALESCE(ug.silver_trophies, 0) * 30 +
    -- Bronze trophies: 15 XP each
    COALESCE(ug.bronze_trophies, 0) * 15 +
    -- Xbox achievements: 1 XP each
    COALESCE(ug.xbox_achievements_earned, 0) * 1
  ) as total_statusxp
FROM user_games ug
GROUP BY ug.user_id;

-- Step 8: Enable RLS and create policies
ALTER TABLE game_titles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

-- Service role has full access (bypasses RLS by default, but explicit policies help)
CREATE POLICY "Service role full access to game_titles" ON game_titles FOR ALL USING (true);
CREATE POLICY "Service role full access to user_games" ON user_games FOR ALL USING (true);
CREATE POLICY "Service role full access to achievements" ON achievements FOR ALL USING (true);
CREATE POLICY "Service role full access to user_achievements" ON user_achievements FOR ALL USING (true);
CREATE POLICY "Service role full access to user_stats" ON user_stats FOR ALL USING (true);

-- Users can view their own data
CREATE POLICY "Users view own user_games" ON user_games FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users view own user_achievements" ON user_achievements FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users view own user_stats" ON user_stats FOR SELECT USING (auth.uid() = user_id);

-- Everyone can read game_titles and achievements (public data)
CREATE POLICY "Anyone view game_titles" ON game_titles FOR SELECT USING (true);
CREATE POLICY "Anyone view achievements" ON achievements FOR SELECT USING (true);

-- Grant view access
GRANT SELECT ON user_statusxp_summary TO authenticated, anon;

-- Done! Now just re-sync PSN, Xbox, and Steam to populate with clean data.
SELECT 'Migration complete! Re-sync all platforms to populate data.' as status;
