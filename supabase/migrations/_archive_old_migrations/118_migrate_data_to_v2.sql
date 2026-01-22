-- Migration 118: Migrate data from old schema to v2 with deduplication
-- This script handles:
-- 1. Deduplicating game_titles -> games_v2
-- 2. Migrating user_games -> user_progress_v2
-- 3. Migrating achievements -> achievements_v2
-- 4. Migrating user_achievements -> user_achievements_v2
-- 5. Populating leaderboard caches

-- ============================================================================
-- STEP 1: Migrate games with deduplication
-- ============================================================================

-- For Xbox games: use xbox_title_id as platform_game_id
INSERT INTO games_v2 (platform_id, platform_game_id, name, cover_url, icon_url, metadata, created_at, updated_at)
SELECT DISTINCT ON (p.id, gt.xbox_title_id)
  p.id as platform_id,
  gt.xbox_title_id as platform_game_id,
  gt.name,
  gt.proxied_cover_url as cover_url,
  NULL as icon_url,
  gt.metadata,
  gt.created_at,
  gt.updated_at
FROM game_titles gt
CROSS JOIN platforms p
WHERE gt.xbox_title_id IS NOT NULL
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
ON CONFLICT (platform_id, platform_game_id) DO UPDATE
  SET name = EXCLUDED.name,
      cover_url = EXCLUDED.cover_url,
      metadata = EXCLUDED.metadata,
      updated_at = EXCLUDED.updated_at;

-- For PSN games: use psn_npwr_id as platform_game_id
INSERT INTO games_v2 (platform_id, platform_game_id, name, cover_url, icon_url, metadata, created_at, updated_at)
SELECT DISTINCT ON (p.id, gt.psn_npwr_id)
  p.id as platform_id,
  gt.psn_npwr_id as platform_game_id,
  gt.name,
  gt.proxied_cover_url as cover_url,
  NULL as icon_url,
  gt.metadata,
  gt.created_at,
  gt.updated_at
FROM game_titles gt
CROSS JOIN platforms p
WHERE gt.psn_npwr_id IS NOT NULL
  AND p.code = 'PSN'
ON CONFLICT (platform_id, platform_game_id) DO UPDATE
  SET name = EXCLUDED.name,
      cover_url = EXCLUDED.cover_url,
      metadata = EXCLUDED.metadata,
      updated_at = EXCLUDED.updated_at;

-- For Steam games: use steam_app_id as platform_game_id
INSERT INTO games_v2 (platform_id, platform_game_id, name, cover_url, icon_url, metadata, created_at, updated_at)
SELECT DISTINCT ON (p.id, gt.steam_app_id)
  p.id as platform_id,
  gt.steam_app_id as platform_game_id,
  gt.name,
  gt.proxied_cover_url as cover_url,
  NULL as icon_url,
  gt.metadata,
  gt.created_at,
  gt.updated_at
FROM game_titles gt
CROSS JOIN platforms p
WHERE gt.steam_app_id IS NOT NULL
  AND p.code = 'STEAM'
ON CONFLICT (platform_id, platform_game_id) DO UPDATE
  SET name = EXCLUDED.name,
      cover_url = EXCLUDED.cover_url,
      metadata = EXCLUDED.metadata,
      updated_at = EXCLUDED.updated_at;

-- ============================================================================
-- STEP 2: Migrate user progress with proper platform mapping
-- ============================================================================

-- Xbox user_games -> user_progress_v2
-- Only migrate entries where game has valid xbox_title_id
INSERT INTO user_progress_v2 (
  user_id, platform_id, platform_game_id,
  current_score, achievements_earned, total_achievements, completion_percentage,
  first_played_at, last_played_at, synced_at, metadata
)
SELECT DISTINCT ON (ug.user_id, ug.platform_id, gt.xbox_title_id)
  ug.user_id,
  ug.platform_id,
  gt.xbox_title_id as platform_game_id,
  ug.xbox_current_gamerscore as current_score,
  ug.xbox_achievements_earned as achievements_earned,
  ug.xbox_total_achievements as total_achievements,
  ug.completion_percent as completion_percentage,
  NULL as first_played_at,
  ug.last_played_at,
  COALESCE(ug.xbox_last_updated_at, ug.updated_at) as synced_at,
  '{}'::jsonb as metadata
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE gt.xbox_title_id IS NOT NULL
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore IS NOT NULL
ON CONFLICT (user_id, platform_id, platform_game_id) DO UPDATE
  SET current_score = GREATEST(user_progress_v2.current_score, EXCLUDED.current_score),
      achievements_earned = GREATEST(user_progress_v2.achievements_earned, EXCLUDED.achievements_earned),
      total_achievements = GREATEST(user_progress_v2.total_achievements, EXCLUDED.total_achievements),
      completion_percentage = GREATEST(user_progress_v2.completion_percentage, EXCLUDED.completion_percentage),
      last_played_at = GREATEST(user_progress_v2.last_played_at, EXCLUDED.last_played_at),
      synced_at = EXCLUDED.synced_at;

-- PSN user_games -> user_progress_v2
-- Use trophy count as current_score
INSERT INTO user_progress_v2 (
  user_id, platform_id, platform_game_id,
  current_score, achievements_earned, total_achievements, completion_percentage,
  first_played_at, last_played_at, synced_at, metadata
)
SELECT DISTINCT ON (ug.user_id, ug.platform_id, gt.psn_npwr_id)
  ug.user_id,
  ug.platform_id,
  gt.psn_npwr_id as platform_game_id,
  COALESCE(ug.earned_trophies, 0) as current_score,
  COALESCE(ug.earned_trophies, 0) as achievements_earned,
  COALESCE(ug.total_trophies, 0) as total_achievements,
  ug.completion_percent as completion_percentage,
  NULL as first_played_at,
  ug.last_played_at,
  ug.updated_at as synced_at,
  jsonb_build_object(
    'platinum', ug.platinum_trophies,
    'gold', ug.gold_trophies,
    'silver', ug.silver_trophies,
    'bronze', ug.bronze_trophies
  ) as metadata
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE gt.psn_npwr_id IS NOT NULL
  AND p.code = 'PSN'
ON CONFLICT (user_id, platform_id, platform_game_id) DO UPDATE
  SET current_score = GREATEST(user_progress_v2.current_score, EXCLUDED.current_score),
      achievements_earned = GREATEST(user_progress_v2.achievements_earned, EXCLUDED.achievements_earned),
      total_achievements = GREATEST(user_progress_v2.total_achievements, EXCLUDED.total_achievements),
      completion_percentage = GREATEST(user_progress_v2.completion_percentage, EXCLUDED.completion_percentage),
      last_played_at = GREATEST(user_progress_v2.last_played_at, EXCLUDED.last_played_at),
      synced_at = EXCLUDED.synced_at,
      metadata = EXCLUDED.metadata;

-- Steam user_games -> user_progress_v2
-- NOTE: Steam-specific columns don't exist in user_games yet
-- This migration will be empty until Steam sync is implemented
-- Keeping this section as a placeholder for future Steam support

-- ============================================================================
-- STEP 3: Migrate achievements catalog
-- ============================================================================

-- Migrate Xbox achievements
INSERT INTO achievements_v2 (
  platform_id, platform_game_id, platform_achievement_id,
  name, description, icon_url, rarity_global, score_value, metadata, created_at
)
SELECT DISTINCT ON (p.id, gt.xbox_title_id, a.platform_achievement_id)
  p.id as platform_id,
  gt.xbox_title_id as platform_game_id,
  a.platform_achievement_id as platform_achievement_id,
  a.name,
  a.description,
  COALESCE(a.proxied_icon_url, a.icon_url) as icon_url,
  a.rarity_global,
  COALESCE(a.xbox_gamerscore, 0) as score_value,
  jsonb_build_object(
    'is_secret', a.xbox_is_secret,
    'is_dlc', a.is_dlc,
    'dlc_name', a.dlc_name
  ) as metadata,
  a.created_at
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
CROSS JOIN platforms p
WHERE a.platform IN ('xbox', 'xboxone', 'xbox360', 'xboxseriesx')
  AND gt.xbox_title_id IS NOT NULL
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
ON CONFLICT (platform_id, platform_game_id, platform_achievement_id) DO UPDATE
  SET name = EXCLUDED.name,
      description = EXCLUDED.description,
      icon_url = EXCLUDED.icon_url,
      rarity_global = EXCLUDED.rarity_global,
      score_value = EXCLUDED.score_value,
      metadata = EXCLUDED.metadata;

-- Migrate PSN achievements (from unified achievements table)
INSERT INTO achievements_v2 (
  platform_id, platform_game_id, platform_achievement_id,
  name, description, icon_url, rarity_global, score_value, metadata, created_at
)
SELECT DISTINCT ON (p.id, gt.psn_npwr_id, a.platform_achievement_id)
  p.id as platform_id,
  gt.psn_npwr_id as platform_game_id,
  a.platform_achievement_id as platform_achievement_id,
  a.name,
  a.description,
  COALESCE(a.proxied_icon_url, a.icon_url) as icon_url,
  a.rarity_global,
  CASE a.psn_trophy_type
    WHEN 'platinum' THEN 300
    WHEN 'gold' THEN 90
    WHEN 'silver' THEN 30
    WHEN 'bronze' THEN 15
    ELSE 0
  END as score_value,
  jsonb_build_object(
    'trophy_type', a.psn_trophy_type,
    'is_platinum', a.is_platinum,
    'is_dlc', a.is_dlc
  ) as metadata,
  a.created_at
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
CROSS JOIN platforms p
WHERE a.platform = 'psn'
  AND gt.psn_npwr_id IS NOT NULL
  AND p.code = 'PSN'
ON CONFLICT (platform_id, platform_game_id, platform_achievement_id) DO UPDATE
  SET name = EXCLUDED.name,
      description = EXCLUDED.description,
      icon_url = EXCLUDED.icon_url,
      rarity_global = EXCLUDED.rarity_global,
      score_value = EXCLUDED.score_value,
      metadata = EXCLUDED.metadata;

-- Migrate Steam achievements
INSERT INTO achievements_v2 (
  platform_id, platform_game_id, platform_achievement_id,
  name, description, icon_url, rarity_global, score_value, metadata, created_at
)
SELECT DISTINCT ON (p.id, gt.steam_app_id, a.platform_achievement_id)
  p.id as platform_id,
  gt.steam_app_id as platform_game_id,
  a.platform_achievement_id as platform_achievement_id,
  a.name,
  a.description,
  COALESCE(a.proxied_icon_url, a.icon_url) as icon_url,
  a.rarity_global,
  0 as score_value,
  jsonb_build_object('steam_hidden', a.steam_hidden) as metadata,
  a.created_at
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
CROSS JOIN platforms p
WHERE a.platform = 'steam'
  AND gt.steam_app_id IS NOT NULL
  AND p.code = 'STEAM'
ON CONFLICT (platform_id, platform_game_id, platform_achievement_id) DO UPDATE
  SET name = EXCLUDED.name,
      description = EXCLUDED.description,
      icon_url = EXCLUDED.icon_url,
      rarity_global = EXCLUDED.rarity_global,
      metadata = EXCLUDED.metadata;

-- ============================================================================
-- STEP 4: Migrate earned achievements/trophies
-- ============================================================================

-- Migrate Xbox earned achievements
INSERT INTO user_achievements_v2 (
  user_id, platform_id, platform_game_id, platform_achievement_id,
  earned_at, synced_at
)
SELECT DISTINCT ON (ua.user_id, p.id, gt.xbox_title_id, a.platform_achievement_id)
  ua.user_id,
  p.id as platform_id,
  gt.xbox_title_id as platform_game_id,
  a.platform_achievement_id as platform_achievement_id,
  ua.earned_at,
  ua.created_at as synced_at
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
CROSS JOIN platforms p
WHERE a.platform IN ('xbox', 'xboxone', 'xbox360', 'xboxseriesx')
  AND gt.xbox_title_id IS NOT NULL
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ua.earned_at IS NOT NULL
ON CONFLICT (user_id, platform_id, platform_game_id, platform_achievement_id) DO UPDATE
  SET earned_at = LEAST(user_achievements_v2.earned_at, EXCLUDED.earned_at),
      synced_at = EXCLUDED.synced_at;

-- Migrate PSN earned achievements (from unified user_achievements table)
INSERT INTO user_achievements_v2 (
  user_id, platform_id, platform_game_id, platform_achievement_id,
  earned_at, synced_at
)
SELECT DISTINCT ON (ua.user_id, p.id, gt.psn_npwr_id, a.platform_achievement_id)
  ua.user_id,
  p.id as platform_id,
  gt.psn_npwr_id as platform_game_id,
  a.platform_achievement_id as platform_achievement_id,
  ua.earned_at,
  ua.created_at as synced_at
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
CROSS JOIN platforms p
WHERE a.platform = 'psn'
  AND gt.psn_npwr_id IS NOT NULL
  AND p.code = 'PSN'
  AND ua.earned_at IS NOT NULL
ON CONFLICT (user_id, platform_id, platform_game_id, platform_achievement_id) DO UPDATE
  SET earned_at = LEAST(user_achievements_v2.earned_at, EXCLUDED.earned_at),
      synced_at = EXCLUDED.synced_at;

-- Migrate Steam earned achievements
INSERT INTO user_achievements_v2 (
  user_id, platform_id, platform_game_id, platform_achievement_id,
  earned_at, synced_at
)
SELECT DISTINCT ON (ua.user_id, p.id, gt.steam_app_id, a.platform_achievement_id)
  ua.user_id,
  p.id as platform_id,
  gt.steam_app_id as platform_game_id,
  a.platform_achievement_id as platform_achievement_id,
  ua.earned_at,
  ua.created_at as synced_at
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
CROSS JOIN platforms p
WHERE a.platform = 'steam'
  AND gt.steam_app_id IS NOT NULL
  AND p.code = 'STEAM'
  AND ua.earned_at IS NOT NULL
ON CONFLICT (user_id, platform_id, platform_game_id, platform_achievement_id) DO UPDATE
  SET earned_at = LEAST(user_achievements_v2.earned_at, EXCLUDED.earned_at),
      synced_at = EXCLUDED.synced_at;

-- ============================================================================
-- STEP 5: Report migration summary
-- ============================================================================

DO $$
DECLARE
  games_count INT;
  user_progress_count INT;
  achievements_count INT;
  user_achievements_count INT;
BEGIN
  SELECT COUNT(*) INTO games_count FROM games_v2;
  SELECT COUNT(*) INTO user_progress_count FROM user_progress_v2;
  SELECT COUNT(*) INTO achievements_count FROM achievements_v2;
  SELECT COUNT(*) INTO user_achievements_count FROM user_achievements_v2;
  
  RAISE NOTICE 'Migration Summary:';
  RAISE NOTICE '  games_v2: % entries', games_count;
  RAISE NOTICE '  user_progress_v2: % entries', user_progress_count;
  RAISE NOTICE '  achievements_v2: % entries', achievements_count;
  RAISE NOTICE '  user_achievements_v2: % entries', user_achievements_count;
END $$;
