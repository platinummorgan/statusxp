-- Migration 117: Create new optimized schema alongside existing tables
-- Phase 2 of DATABASE_REDESIGN.md
-- This structure prevents duplicates by design using composite primary keys

-- ============================================================================
-- PLATFORMS (already exists, but verify structure)
-- ============================================================================

-- ============================================================================
-- NEW: games_v2 - One entry per platform-specific game
-- ============================================================================
CREATE TABLE IF NOT EXISTS games_v2 (
  platform_id BIGINT NOT NULL REFERENCES platforms(id),
  platform_game_id TEXT NOT NULL,  -- xbox_title_id, psn_npwr_id, or steam_app_id
  name TEXT NOT NULL,
  cover_url TEXT,
  icon_url TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  PRIMARY KEY (platform_id, platform_game_id)
);

CREATE INDEX IF NOT EXISTS idx_games_v2_name ON games_v2(name);
CREATE INDEX IF NOT EXISTS idx_games_v2_platform ON games_v2(platform_id);

-- ============================================================================
-- NEW: user_progress_v2 - One entry per user-platform-game combination
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_progress_v2 (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  platform_id BIGINT NOT NULL,
  platform_game_id TEXT NOT NULL,
  
  -- Progress metrics
  current_score INT DEFAULT 0,  -- Gamerscore, trophy count, or achievement count
  achievements_earned INT DEFAULT 0,
  total_achievements INT DEFAULT 0,
  completion_percentage NUMERIC(5,2) DEFAULT 0,
  
  -- Timestamps
  first_played_at TIMESTAMPTZ,
  last_played_at TIMESTAMPTZ,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Metadata
  metadata JSONB DEFAULT '{}'::jsonb,
  
  PRIMARY KEY (user_id, platform_id, platform_game_id),
  FOREIGN KEY (platform_id, platform_game_id) REFERENCES games_v2(platform_id, platform_game_id)
);

CREATE INDEX IF NOT EXISTS idx_user_progress_v2_user ON user_progress_v2(user_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_v2_platform ON user_progress_v2(platform_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_v2_game ON user_progress_v2(platform_id, platform_game_id);
CREATE INDEX IF NOT EXISTS idx_user_progress_v2_score ON user_progress_v2(user_id, current_score) WHERE current_score > 0;

-- ============================================================================
-- NEW: achievements_v2 - One entry per platform-specific achievement
-- ============================================================================
CREATE TABLE IF NOT EXISTS achievements_v2 (
  platform_id BIGINT NOT NULL,
  platform_game_id TEXT NOT NULL,
  platform_achievement_id TEXT NOT NULL,
  
  name TEXT NOT NULL,
  description TEXT,
  icon_url TEXT,
  rarity_global NUMERIC(5,2),
  score_value INT DEFAULT 0,  -- Gamerscore or trophy value
  
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  PRIMARY KEY (platform_id, platform_game_id, platform_achievement_id),
  FOREIGN KEY (platform_id, platform_game_id) REFERENCES games_v2(platform_id, platform_game_id)
);

CREATE INDEX IF NOT EXISTS idx_achievements_v2_game ON achievements_v2(platform_id, platform_game_id);
CREATE INDEX IF NOT EXISTS idx_achievements_v2_rarity ON achievements_v2(rarity_global) WHERE rarity_global IS NOT NULL;

-- ============================================================================
-- NEW: user_achievements_v2 - Earned achievements
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_achievements_v2 (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  platform_id BIGINT NOT NULL,
  platform_game_id TEXT NOT NULL,
  platform_achievement_id TEXT NOT NULL,
  
  earned_at TIMESTAMPTZ NOT NULL,
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  
  PRIMARY KEY (user_id, platform_id, platform_game_id, platform_achievement_id),
  FOREIGN KEY (platform_id, platform_game_id, platform_achievement_id) 
    REFERENCES achievements_v2(platform_id, platform_game_id, platform_achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_v2_user ON user_achievements_v2(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_v2_earned ON user_achievements_v2(earned_at);

-- ============================================================================
-- NEW: Leaderboard cache tables for v2 schema
-- ============================================================================

CREATE TABLE IF NOT EXISTS xbox_leaderboard_cache_v2 (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  gamerscore INT NOT NULL DEFAULT 0,
  achievement_count INT NOT NULL DEFAULT 0,
  total_games INT NOT NULL DEFAULT 0,
  avatar_url TEXT,
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_xbox_leaderboard_v2_score ON xbox_leaderboard_cache_v2(gamerscore DESC);

-- Similar tables for PSN and Steam
CREATE TABLE IF NOT EXISTS psn_leaderboard_cache_v2 (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  trophy_count INT NOT NULL DEFAULT 0,
  platinum_count INT NOT NULL DEFAULT 0,
  gold_count INT NOT NULL DEFAULT 0,
  silver_count INT NOT NULL DEFAULT 0,
  bronze_count INT NOT NULL DEFAULT 0,
  total_games INT NOT NULL DEFAULT 0,
  avatar_url TEXT,
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS steam_leaderboard_cache_v2 (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  achievement_count INT NOT NULL DEFAULT 0,
  perfect_games INT NOT NULL DEFAULT 0,
  total_games INT NOT NULL DEFAULT 0,
  avatar_url TEXT,
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- Comments for documentation
-- ============================================================================

COMMENT ON TABLE games_v2 IS 'Platform-specific games. Composite PK prevents duplicates.';
COMMENT ON TABLE user_progress_v2 IS 'User progress per platform-specific game. Composite PK prevents duplicates.';
COMMENT ON TABLE achievements_v2 IS 'Platform-specific achievements. Composite PK ensures uniqueness.';
COMMENT ON TABLE user_achievements_v2 IS 'Earned achievements. Composite PK prevents duplicate earnings.';

COMMENT ON COLUMN games_v2.platform_game_id IS 'xbox_title_id, psn_npwr_id, or steam_app_id depending on platform';
COMMENT ON COLUMN user_progress_v2.current_score IS 'Gamerscore (Xbox), trophy points (PSN), or achievement count (Steam)';
