-- Fix ALL leaderboards for V2 schema
-- Creates views that aggregate data from user_achievements

-- ============================================================================
-- PSN LEADERBOARD
-- ============================================================================

DROP VIEW IF EXISTS psn_leaderboard_cache CASCADE;

CREATE OR REPLACE VIEW psn_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.display_name, p.username, 'Player') as display_name,
  p.avatar_url,
  -- Count total PSN trophies earned by type (using _count suffix for Dart compatibility)
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END) as bronze_count,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END) as silver_count,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END) as gold_count,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'platinum' THEN 1 ELSE 0 END) as platinum_count,
  -- Total trophies
  COUNT(*) as total_trophies,
  -- Total games
  COUNT(DISTINCT a.platform_game_id) as total_games,
  NOW() as updated_at
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
INNER JOIN profiles p ON p.id = ua.user_id
WHERE ua.platform_id = 1  -- PSN only
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.display_name, p.username, p.avatar_url
HAVING COUNT(*) > 0
ORDER BY platinum_count DESC, gold_count DESC, silver_count DESC, bronze_count DESC;

GRANT SELECT ON psn_leaderboard_cache TO authenticated;

-- ============================================================================
-- STEAM LEADERBOARD
-- ============================================================================

DROP VIEW IF EXISTS steam_leaderboard_cache CASCADE;

CREATE OR REPLACE VIEW steam_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.display_name, p.username, 'Player') as display_name,
  p.avatar_url,
  -- Count total Steam achievements
  COUNT(DISTINCT a.platform_achievement_id) as achievement_count,
  -- Count total Steam games
  COUNT(DISTINCT a.platform_game_id) as total_games,
  -- Calculate completion percentage (achievements / total possible)
  CASE 
    WHEN COUNT(DISTINCT a.platform_game_id) > 0 
    THEN (COUNT(DISTINCT a.platform_achievement_id)::NUMERIC / NULLIF(COUNT(DISTINCT a.platform_game_id), 0) * 100)
    ELSE 0
  END as avg_completion,
  NOW() as updated_at
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
INNER JOIN profiles p ON p.id = ua.user_id
WHERE ua.platform_id = 5  -- Steam only
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.display_name, p.username, p.avatar_url
HAVING COUNT(DISTINCT a.platform_achievement_id) > 0
ORDER BY achievement_count DESC, total_games DESC;

GRANT SELECT ON steam_leaderboard_cache TO authenticated;

-- ============================================================================
-- XBOX LEADERBOARD
-- ============================================================================

DROP VIEW IF EXISTS xbox_leaderboard_cache CASCADE;

CREATE OR REPLACE VIEW xbox_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.display_name, p.username, 'Player') as display_name,
  p.avatar_url,
  -- Sum gamerscore from all Xbox achievements
  SUM(a.score_value) as gamerscore,
  -- Count total Xbox achievements
  COUNT(DISTINCT a.platform_achievement_id) as achievement_count,
  -- Count total Xbox games
  COUNT(DISTINCT a.platform_game_id) as total_games,
  NOW() as updated_at
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
INNER JOIN profiles p ON p.id = ua.user_id
WHERE ua.platform_id IN (10, 11, 12)  -- Xbox 360, Xbox One, Xbox Series X
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.display_name, p.username, p.avatar_url
HAVING COUNT(DISTINCT a.platform_achievement_id) > 0
ORDER BY gamerscore DESC, total_games DESC;

GRANT SELECT ON xbox_leaderboard_cache TO authenticated;

-- ============================================================================
-- GLOBAL LEADERBOARD (StatusXP)
-- ============================================================================

DROP VIEW IF EXISTS leaderboard_global_cache CASCADE;

CREATE OR REPLACE VIEW leaderboard_global_cache AS
WITH user_statusxp AS (
  SELECT 
    ua.user_id,
    -- Calculate StatusXP: base 100 × rarity multiplier (original system)
    SUM(
      CASE 
        -- Ultra Rare (≤1%): 300 points (100 × 3.0)
        WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 1.0 THEN 300
        -- Very Rare (1-5%): 225 points (100 × 2.25)
        WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 5.0 THEN 225
        -- Rare (5-10%): 175 points (100 × 1.75)
        WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 10.0 THEN 175
        -- Uncommon (10-25%): 125 points (100 × 1.25)
        WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 25.0 THEN 125
        -- Common (>25%): 100 points (100 × 1.0)
        WHEN a.rarity_global IS NOT NULL THEN 100
        -- No rarity data: 100 points (default to common)
        ELSE 100
      END
    ) as statusxp,
    -- Total achievements across all platforms
    COUNT(DISTINCT (a.platform_id, a.platform_game_id, a.platform_achievement_id)) as total_achievements,
    -- Total games across all platforms
    COUNT(DISTINCT (a.platform_id, a.platform_game_id)) as total_games
  FROM user_achievements ua
  INNER JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  GROUP BY ua.user_id
)
SELECT 
  ROW_NUMBER() OVER (ORDER BY us.statusxp DESC, us.total_achievements DESC) as rank,
  us.user_id,
  COALESCE(p.display_name, p.username, 'Player') as display_name,
  p.avatar_url,
  us.statusxp,
  us.total_achievements,
  us.total_games,
  NOW() as updated_at
FROM user_statusxp us
INNER JOIN profiles p ON p.id = us.user_id
WHERE p.show_on_leaderboard = true
  AND us.statusxp > 0
ORDER BY us.statusxp DESC, us.total_achievements DESC;

GRANT SELECT ON leaderboard_global_cache TO authenticated;

-- ============================================================================
-- REFRESH FUNCTIONS (no-ops since these are views)
-- ============================================================================

CREATE OR REPLACE FUNCTION refresh_psn_leaderboard_cache()
RETURNS void AS $$
BEGIN
  RAISE NOTICE 'PSN leaderboard cache is a view - automatically up to date';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_steam_leaderboard_cache()
RETURNS void AS $$
BEGIN
  RAISE NOTICE 'Steam leaderboard cache is a view - automatically up to date';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void AS $$
BEGIN
  RAISE NOTICE 'Xbox leaderboard cache is a view - automatically up to date';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION refresh_leaderboard_global_cache()
RETURNS void AS $$
BEGIN
  RAISE NOTICE 'Global leaderboard cache is a view - automatically up to date';
END;
$$ LANGUAGE plpgsql;
