-- Optimized PSN leaderboard cache - uses user_games data directly
CREATE OR REPLACE FUNCTION refresh_psn_leaderboard_cache()
RETURNS void AS $$
BEGIN
  TRUNCATE psn_leaderboard_cache;
  
  INSERT INTO psn_leaderboard_cache (user_id, display_name, avatar_url, platinum_count, total_games, updated_at)
  SELECT 
    p.id,
    p.psn_online_id,
    p.psn_avatar_url,
    COALESCE(psn_data.platinum_count, 0) as platinum_count,
    COALESCE(psn_data.total_games, 0) as total_games,
    NOW()
  FROM profiles p
  LEFT JOIN (
    SELECT 
      user_id, 
      COUNT(DISTINCT game_title_id) as total_games,
      SUM(platinum_trophies) as platinum_count
    FROM user_games
    WHERE platform_id IN (1, 2, 5, 9)  -- PS5, PS4, PS3, Vita
    GROUP BY user_id
  ) psn_data ON psn_data.user_id = p.id
  WHERE p.show_on_leaderboard = true
    AND p.psn_account_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

SELECT refresh_psn_leaderboard_cache();

SELECT * FROM psn_leaderboard_cache 
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
