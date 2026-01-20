-- Fix Xbox leaderboard to ONLY count games that have xbox_title_id
-- This prevents PSN/Steam games from inflating Xbox gamerscore
CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  DELETE FROM xbox_leaderboard_cache;
  
  INSERT INTO xbox_leaderboard_cache (user_id, display_name, gamerscore, achievement_count, total_games, avatar_url)
  SELECT 
    ug.user_id,
    COALESCE(p.xbox_gamertag, p.display_name) as display_name,
    SUM(ug.xbox_current_gamerscore) as gamerscore,
    SUM(ug.xbox_achievements_earned) as achievement_count,
    COUNT(DISTINCT gt.xbox_title_id) as total_games,  -- Count distinct Xbox title IDs only
    p.xbox_avatar_url as avatar_url
  FROM user_games ug
  JOIN profiles p ON p.id = ug.user_id
  JOIN game_titles gt ON gt.id = ug.game_title_id
  WHERE p.show_on_leaderboard = true
    AND ug.xbox_current_gamerscore > 0
    AND gt.xbox_title_id IS NOT NULL  -- CRITICAL: Only count games with Xbox IDs
  GROUP BY ug.user_id, p.xbox_gamertag, p.display_name, p.xbox_avatar_url
  ORDER BY gamerscore DESC;
END;
$$;

-- Refresh the cache with correct data
SELECT refresh_xbox_leaderboard_cache();

-- Check Gordon's corrected totals
SELECT 
  display_name,
  gamerscore,
  total_games,
  achievement_count
FROM xbox_leaderboard_cache
WHERE display_name = 'XxlmThumperxX';
