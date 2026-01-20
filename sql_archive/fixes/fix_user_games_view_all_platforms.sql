-- ============================================================================
-- FIX user_games VIEW - Include ALL platforms (PSN, Xbox, Steam)
-- ============================================================================
-- Problem: user_games view only shows PSN data (platform_id = 1)
-- Solution: Include all platforms with platform-specific trophy/achievement data
-- ============================================================================

DROP VIEW IF EXISTS user_games CASCADE;

CREATE OR REPLACE VIEW user_games AS
WITH user_game_progress AS (
  -- Get all games a user has progress on, from user_progress
  SELECT 
    up.user_id,
    up.platform_id,
    up.platform_game_id,
    up.achievements_earned as earned_trophies,
    up.total_achievements as total_trophies,
    up.completion_percentage,
    up.current_score,  -- Xbox gamerscore
    up.last_played_at,
    -- Generate synthetic game_title_id from platform_id and platform_game_id
    ('x' || substr(md5(up.platform_id::text || '_' || up.platform_game_id), 1, 15))::bit(60)::bigint as game_title_id,
    g.name
  FROM user_progress up
  INNER JOIN games g ON 
    g.platform_id = up.platform_id 
    AND g.platform_game_id = up.platform_game_id
),
psn_trophy_breakdown AS (
  -- Get PSN trophy breakdown from user_achievements
  SELECT
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    COUNT(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 END) as bronze_trophies,
    COUNT(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 END) as silver_trophies,
    COUNT(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 END) as gold_trophies,
    COUNT(CASE WHEN a.metadata->>'psn_trophy_type' = 'platinum' THEN 1 END) as platinum_trophies,
    MAX(ua.earned_at) as last_trophy_earned_at,
    EXISTS (
      SELECT 1 FROM achievements a2 
      WHERE a2.platform_id = ua.platform_id 
        AND a2.platform_game_id = ua.platform_game_id 
        AND a2.metadata->>'psn_trophy_type' = 'platinum'
    ) as has_platinum
  FROM user_achievements ua
  INNER JOIN achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.platform_id = 1  -- PSN only
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
)
SELECT 
  ROW_NUMBER() OVER (ORDER BY ugp.user_id, ugp.platform_id, ugp.platform_game_id) AS id,
  ugp.user_id,
  ugp.game_title_id,
  ugp.platform_id,
  ugp.name as game_title,
  
  -- PSN-specific fields (null for other platforms)
  COALESCE(psn.has_platinum, false) as has_platinum,
  COALESCE(psn.bronze_trophies, 0) as bronze_trophies,
  COALESCE(psn.silver_trophies, 0) as silver_trophies,
  COALESCE(psn.gold_trophies, 0) as gold_trophies,
  COALESCE(psn.platinum_trophies, 0) as platinum_trophies,
  COALESCE(psn.last_trophy_earned_at, ugp.last_played_at) as last_trophy_earned_at,
  
  -- Universal fields (all platforms)
  ugp.total_trophies,
  ugp.earned_trophies,
  ugp.completion_percentage as completion_percent,
  ugp.last_played_at,
  ugp.current_score,  -- Xbox gamerscore, null for PSN/Steam
  
  NOW() as created_at,
  NOW() as updated_at
  
FROM user_game_progress ugp
LEFT JOIN psn_trophy_breakdown psn ON 
  psn.user_id = ugp.user_id 
  AND psn.platform_id = ugp.platform_id
  AND psn.platform_game_id = ugp.platform_game_id;

-- Grant access
GRANT SELECT ON user_games TO authenticated;
GRANT SELECT ON user_games TO anon;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Check your games across all platforms
SELECT 
  platform_id,
  CASE platform_id
    WHEN 1 THEN 'PSN'
    WHEN 5 THEN 'Steam'
    WHEN 10 THEN 'Xbox360'
    WHEN 11 THEN 'XboxOne'
    WHEN 12 THEN 'XboxSeriesX'
  END as platform_name,
  COUNT(*) as game_count,
  SUM(earned_trophies) as total_achievements
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY platform_id
ORDER BY platform_id;

-- Show sample Xbox games
SELECT 
  game_title,
  platform_id,
  earned_trophies,
  total_trophies,
  current_score as gamerscore
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
LIMIT 10;
