-- Phase 1: Add Critical Indexes to Current Tables (Based on Actual Schema)
-- This reduces disk I/O immediately while we build new structure

-- ============================================================================
-- GAME_TITLES indexes
-- ============================================================================

-- Index for game name lookups (used in deduplication)
CREATE INDEX IF NOT EXISTS idx_game_titles_name ON game_titles(name);

-- Index for platform-specific lookups
CREATE INDEX IF NOT EXISTS idx_game_titles_xbox ON game_titles(xbox_title_id) WHERE xbox_title_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_game_titles_psn ON game_titles(psn_npwr_id) WHERE psn_npwr_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_game_titles_steam ON game_titles(steam_app_id) WHERE steam_app_id IS NOT NULL;

-- ============================================================================
-- USER_GAMES indexes (Primary performance bottleneck)
-- ============================================================================

-- Composite index for user + platform queries (most common)
CREATE INDEX IF NOT EXISTS idx_user_games_user_platform ON user_games(user_id, platform_id);

-- Index for game_title_id joins
CREATE INDEX IF NOT EXISTS idx_user_games_game ON user_games(game_title_id);

-- Index for platform filtering
CREATE INDEX IF NOT EXISTS idx_user_games_platform ON user_games(platform_id);

-- Index for Xbox gamerscore queries (critical for leaderboard)
CREATE INDEX IF NOT EXISTS idx_user_games_xbox_score ON user_games(user_id, xbox_current_gamerscore) 
  WHERE xbox_current_gamerscore IS NOT NULL AND xbox_current_gamerscore > 0;

-- Index for last played sorting
CREATE INDEX IF NOT EXISTS idx_user_games_last_played ON user_games(user_id, last_played_at DESC NULLS LAST);

-- Composite index for user + game + platform (prevents duplicate lookups)
CREATE INDEX IF NOT EXISTS idx_user_games_user_game_platform ON user_games(user_id, game_title_id, platform_id);

-- ============================================================================
-- USER_ACHIEVEMENTS indexes
-- ============================================================================

-- Composite index for user + achievement lookups
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_ach ON user_achievements(user_id, achievement_id);

-- Index for achievement_id joins
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement ON user_achievements(achievement_id);

-- Index for earned_at sorting (recent achievements)
CREATE INDEX IF NOT EXISTS idx_user_achievements_earned ON user_achievements(user_id, earned_at DESC);

-- ============================================================================
-- ACHIEVEMENTS indexes
-- ============================================================================

-- Index for game_title_id joins (most common)
CREATE INDEX IF NOT EXISTS idx_achievements_game ON achievements(game_title_id);

-- Index for platform filtering
CREATE INDEX IF NOT EXISTS idx_achievements_platform ON achievements(platform);

-- Composite index for game + platform queries
CREATE INDEX IF NOT EXISTS idx_achievements_game_platform ON achievements(game_title_id, platform);

-- Index for PSN trophy type queries
CREATE INDEX IF NOT EXISTS idx_achievements_psn_platinum ON achievements(game_title_id, platform, psn_trophy_type) 
  WHERE platform = 'psn' AND psn_trophy_type = 'platinum';

-- Index for rarity queries (CORRECT column name: rarity_global)
CREATE INDEX IF NOT EXISTS idx_achievements_rarity ON achievements(rarity_global) 
  WHERE rarity_global IS NOT NULL;

-- Index for platform_achievement_id lookups
CREATE INDEX IF NOT EXISTS idx_achievements_platform_id ON achievements(platform, platform_achievement_id);

-- ============================================================================
-- PROFILES indexes
-- ============================================================================

-- Index for leaderboard filtering
CREATE INDEX IF NOT EXISTS idx_profiles_leaderboard ON profiles(show_on_leaderboard) 
  WHERE show_on_leaderboard = true;

-- Index for Xbox user lookups
CREATE INDEX IF NOT EXISTS idx_profiles_xbox ON profiles(xbox_xuid) WHERE xbox_xuid IS NOT NULL;

-- Index for PSN user lookups
CREATE INDEX IF NOT EXISTS idx_profiles_psn ON profiles(psn_account_id) WHERE psn_account_id IS NOT NULL;

-- Index for Steam user lookups
CREATE INDEX IF NOT EXISTS idx_profiles_steam ON profiles(steam_id) WHERE steam_id IS NOT NULL;

-- ============================================================================
-- Verify indexes were created
-- ============================================================================

SELECT 
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('game_titles', 'user_games', 'user_achievements', 'achievements', 'profiles')
ORDER BY tablename, indexname;
