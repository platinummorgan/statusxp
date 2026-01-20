-- Fix Xbox leaderboard for V2 schema
-- Creates a view that aggregates Xbox achievements from user_achievements

-- Drop old view/table if exists
DROP VIEW IF EXISTS xbox_leaderboard_cache CASCADE;

-- Create view that mimics the old xbox_leaderboard_cache structure
CREATE OR REPLACE VIEW xbox_leaderboard_cache AS
SELECT 
  ua.user_id,
  COALESCE(p.display_name, p.username, 'Player') as display_name,
  p.avatar_url,
  -- Sum gamerscore from Xbox achievements (platforms 10, 11, 12)
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
WHERE ua.platform_id IN (10, 11, 12)  -- Xbox platforms
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.display_name, p.username, p.avatar_url
HAVING COUNT(DISTINCT a.platform_achievement_id) > 0
ORDER BY gamerscore DESC, total_games DESC;

-- Grant access
GRANT SELECT ON xbox_leaderboard_cache TO authenticated;

-- Create function to "refresh" (just a no-op since it's a view)
CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void AS $$
BEGIN
  -- View auto-refreshes, nothing to do
  RAISE NOTICE 'Xbox leaderboard cache is a view - automatically up to date';
END;
$$ LANGUAGE plpgsql;
