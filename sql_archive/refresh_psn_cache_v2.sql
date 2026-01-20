-- Use v2 schema for PSN leaderboard cache refresh
-- This should be MUCH faster than the old schema queries

CREATE OR REPLACE FUNCTION refresh_psn_leaderboard_cache_v2()
RETURNS void AS $$
BEGIN
  TRUNCATE psn_leaderboard_cache_v2;
  
  INSERT INTO psn_leaderboard_cache_v2 (
    user_id, 
    display_name, 
    avatar_url, 
    platinum_count,
    gold_count,
    silver_count, 
    bronze_count,
    trophy_count,
    total_games, 
    last_updated
  )
  SELECT 
    p.id,
    p.psn_online_id,
    p.psn_avatar_url,
    COALESCE(trophy_counts.platinum_count, 0),
    COALESCE(trophy_counts.gold_count, 0),
    COALESCE(trophy_counts.silver_count, 0),
    COALESCE(trophy_counts.bronze_count, 0),
    COALESCE(trophy_counts.total_trophies, 0),
    COALESCE(games.total_games, 0),
    NOW()
  FROM profiles p
  -- Count games from user_progress_v2 (much simpler join)
  LEFT JOIN (
    SELECT 
      user_id, 
      COUNT(*) as total_games
    FROM user_progress_v2
    WHERE platform_id = 1  -- PSN platform
    GROUP BY user_id
  ) games ON games.user_id = p.id
  -- Count trophies by type from user_achievements_v2 + achievements_v2
  LEFT JOIN (
    SELECT 
      ua.user_id,
      COUNT(*) FILTER (WHERE a.metadata->>'trophy_type' = 'platinum') as platinum_count,
      COUNT(*) FILTER (WHERE a.metadata->>'trophy_type' = 'gold') as gold_count,
      COUNT(*) FILTER (WHERE a.metadata->>'trophy_type' = 'silver') as silver_count,
      COUNT(*) FILTER (WHERE a.metadata->>'trophy_type' = 'bronze') as bronze_count,
      COUNT(*) as total_trophies
    FROM user_achievements_v2 ua
    INNER JOIN achievements_v2 a ON 
      a.platform_id = ua.platform_id AND 
      a.platform_game_id = ua.platform_game_id AND 
      a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.platform_id = 1  -- PSN platform
    GROUP BY ua.user_id
  ) trophy_counts ON trophy_counts.user_id = p.id
  WHERE p.show_on_leaderboard = true
    AND p.psn_account_id IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Test the v2 refresh
SELECT refresh_psn_leaderboard_cache_v2();

-- Check if DanyGT37 appears now
SELECT * FROM psn_leaderboard_cache_v2 
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- Check total count
SELECT COUNT(*) as total_psn_users FROM psn_leaderboard_cache_v2;
