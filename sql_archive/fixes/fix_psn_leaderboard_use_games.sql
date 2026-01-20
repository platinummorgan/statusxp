-- Fix PSN leaderboard to include users even with 0 achievements earned
CREATE OR REPLACE FUNCTION refresh_psn_leaderboard_cache()
RETURNS void AS $$
BEGIN
  TRUNCATE psn_leaderboard_cache;
  
  INSERT INTO psn_leaderboard_cache (user_id, display_name, avatar_url, platinum_count, total_games, updated_at)
  SELECT 
    p.id,
    p.psn_online_id,
    p.psn_avatar_url,
    COUNT(DISTINCT CASE WHEN a.is_platinum = true THEN ua.id END) as platinum_count,
    COUNT(DISTINCT ug.game_title_id) as total_games,
    NOW()
  FROM profiles p
  INNER JOIN user_games ug ON ug.user_id = p.id
  LEFT JOIN user_achievements ua ON ua.user_id = p.id
  LEFT JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'psn'
  WHERE p.show_on_leaderboard = true
    AND p.psn_account_id IS NOT NULL
  GROUP BY p.id, p.psn_online_id, p.psn_avatar_url
  HAVING COUNT(DISTINCT ug.game_title_id) > 0;
END;
$$ LANGUAGE plpgsql;

SELECT refresh_psn_leaderboard_cache();

SELECT * FROM psn_leaderboard_cache 
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
