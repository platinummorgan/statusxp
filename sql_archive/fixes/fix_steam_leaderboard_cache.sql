-- Fix Steam leaderboard cache to include users with 0 achievements
-- Uses same logic as original but with LEFT JOIN to include new users
CREATE OR REPLACE FUNCTION refresh_steam_leaderboard_cache()
RETURNS void AS $$
BEGIN
  TRUNCATE steam_leaderboard_cache;
  
  INSERT INTO steam_leaderboard_cache (user_id, display_name, avatar_url, achievement_count, total_games, updated_at)
  SELECT 
    p.id,
    COALESCE(p.steam_display_name, p.display_name),
    p.steam_avatar_url,
    COALESCE(steam_data.achievement_count, 0) as achievement_count,
    COALESCE(steam_data.total_games, 0) as total_games,
    NOW()
  FROM profiles p
  LEFT JOIN (
    SELECT 
      ua.user_id,
      COUNT(DISTINCT ua.id) as achievement_count,
      COUNT(DISTINCT a.game_title_id) as total_games
    FROM user_achievements ua
    INNER JOIN achievements a ON a.id = ua.achievement_id 
    WHERE a.platform = 'steam'
    GROUP BY ua.user_id
  ) steam_data ON steam_data.user_id = p.id
  WHERE p.show_on_leaderboard = true
    AND p.steam_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Refresh the cache
SELECT refresh_steam_leaderboard_cache();

-- Check if DanyGT37 appears now
SELECT * FROM steam_leaderboard_cache 
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Check total count
SELECT COUNT(*) as total_steam_users FROM steam_leaderboard_cache;
