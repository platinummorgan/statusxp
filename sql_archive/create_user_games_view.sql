-- Create a view that provides game-level stats from user_achievements
-- This replaces the old user_games table for V2 schema

CREATE OR REPLACE VIEW user_games AS
SELECT 
  ROW_NUMBER() OVER (ORDER BY ua.user_id, g.platform_id, g.platform_game_id) AS id,
  ua.user_id,
  g.platform_id,
  g.platform_game_id,
  g.name as game_title,
  
  -- Check if game has a platinum trophy (PSN only, platform_id = 1)
  -- Extract trophy_type from metadata JSON
  CASE 
    WHEN g.platform_id = 1 THEN 
      EXISTS (
        SELECT 1 FROM achievements a 
        WHERE a.platform_id = g.platform_id 
          AND a.platform_game_id = g.platform_game_id 
          AND a.metadata->>'psn_trophy_type' = 'platinum'
      )
    ELSE false
  END as has_platinum,
  
  -- Count bronze trophies earned by user (PSN only)
  COUNT(CASE WHEN g.platform_id = 1 AND a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 END) as bronze_trophies,
  
  -- Count silver trophies earned by user (PSN only)
  COUNT(CASE WHEN g.platform_id = 1 AND a.metadata->>'psn_trophy_type' = 'silver' THEN 1 END) as silver_trophies,
  
  -- Count gold trophies earned by user (PSN only)
  COUNT(CASE WHEN g.platform_id = 1 AND a.metadata->>'psn_trophy_type' = 'gold' THEN 1 END) as gold_trophies,
  
  -- Count platinum trophies earned by user (PSN only)
  COUNT(CASE WHEN g.platform_id = 1 AND a.metadata->>'psn_trophy_type' = 'platinum' THEN 1 END) as platinum_trophies,
  
  -- Total achievements for this game
  COUNT(*) as total_achievements,
  
  MAX(ua.earned_at) as last_played_at,
  MIN(a.created_at) as created_at,
  MAX(a.created_at) as updated_at
  
FROM user_achievements ua
INNER JOIN games g ON 
  g.platform_id = ua.platform_id 
  AND g.platform_game_id = ua.platform_game_id
INNER JOIN achievements a ON
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
GROUP BY ua.user_id, g.platform_id, g.platform_game_id, g.name;

-- Grant access
GRANT SELECT ON user_games TO authenticated;
