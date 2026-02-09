-- Add functions to get user rank for each platform leaderboard
-- These functions calculate rank by counting users with better stats

-- PSN Rank Function
CREATE OR REPLACE FUNCTION get_user_psn_rank(p_user_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rank INT;
  v_user_platinum INT;
  v_user_gold INT;
  v_user_silver INT;
  v_user_bronze INT;
BEGIN
  -- Get current user's trophy counts
  SELECT 
    COALESCE(SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END), 0)
  INTO v_user_platinum, v_user_gold, v_user_silver, v_user_bronze
  FROM user_achievements ua
  JOIN achievements a ON a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id IN (1, 2, 5, 9); -- PS3, PS4, PS5, PSVITA
  
  -- Return NULL if user has no PSN trophies
  IF v_user_platinum = 0 AND v_user_gold = 0 AND v_user_silver = 0 AND v_user_bronze = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Count users ranked better (same ORDER BY logic as view)
  SELECT COUNT(*) + 1 INTO v_rank
  FROM (
    SELECT ua.user_id,
      SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) as platinum_count,
      SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END) as gold_count,
      SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END) as silver_count,
      SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END) as bronze_count
    FROM user_achievements ua
    JOIN achievements a ON a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id 
      AND a.platform_achievement_id = ua.platform_achievement_id
    JOIN profiles p ON p.id = ua.user_id
    WHERE ua.platform_id IN (1, 2, 5, 9)
      AND p.show_on_leaderboard = true
      AND ua.user_id != p_user_id
    GROUP BY ua.user_id
    HAVING COUNT(*) > 0
  ) ranked_users
  WHERE 
    ranked_users.platinum_count > v_user_platinum OR
    (ranked_users.platinum_count = v_user_platinum AND ranked_users.gold_count > v_user_gold) OR
    (ranked_users.platinum_count = v_user_platinum AND ranked_users.gold_count = v_user_gold AND ranked_users.silver_count > v_user_silver) OR
    (ranked_users.platinum_count = v_user_platinum AND ranked_users.gold_count = v_user_gold AND ranked_users.silver_count = v_user_silver AND ranked_users.bronze_count > v_user_bronze);
  
  RETURN v_rank;
END;
$$;
-- Xbox Rank Function
CREATE OR REPLACE FUNCTION get_user_xbox_rank(p_user_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rank INT;
  v_user_gamerscore INT;
  v_user_achievements INT;
BEGIN
  -- Get current user's gamerscore and achievement count
  SELECT 
    COALESCE(SUM((a.metadata->>'xbox_gamerscore')::int), 0),
    COALESCE(COUNT(*), 0)
  INTO v_user_gamerscore, v_user_achievements
  FROM user_achievements ua
  JOIN achievements a ON a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id IN (10, 11, 12); -- Xbox 360, Xbox One, Xbox Series X
  
  -- Return NULL if user has no Xbox achievements
  IF v_user_gamerscore = 0 AND v_user_achievements = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Count users ranked better
  SELECT COUNT(*) + 1 INTO v_rank
  FROM (
    SELECT ua.user_id,
      SUM((a.metadata->>'xbox_gamerscore')::int) as gamerscore,
      COUNT(*) as achievement_count
    FROM user_achievements ua
    JOIN achievements a ON a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id 
      AND a.platform_achievement_id = ua.platform_achievement_id
    JOIN profiles p ON p.id = ua.user_id
    WHERE ua.platform_id IN (10, 11, 12)
      AND p.show_on_leaderboard = true
      AND ua.user_id != p_user_id
    GROUP BY ua.user_id
    HAVING COUNT(*) > 0
  ) ranked_users
  WHERE 
    ranked_users.gamerscore > v_user_gamerscore OR
    (ranked_users.gamerscore = v_user_gamerscore AND ranked_users.achievement_count > v_user_achievements);
  
  RETURN v_rank;
END;
$$;
-- Steam Rank Function
CREATE OR REPLACE FUNCTION get_user_steam_rank(p_user_id UUID)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rank INT;
  v_user_achievements INT;
BEGIN
  -- Get current user's achievement count
  SELECT COALESCE(COUNT(*), 0)
  INTO v_user_achievements
  FROM user_achievements ua
  WHERE ua.user_id = p_user_id
    AND ua.platform_id = 3; -- Steam
  
  -- Return NULL if user has no Steam achievements
  IF v_user_achievements = 0 THEN
    RETURN NULL;
  END IF;
  
  -- Count users ranked better
  SELECT COUNT(*) + 1 INTO v_rank
  FROM (
    SELECT ua.user_id,
      COUNT(*) as achievement_count
    FROM user_achievements ua
    JOIN profiles p ON p.id = ua.user_id
    WHERE ua.platform_id = 3
      AND p.show_on_leaderboard = true
      AND ua.user_id != p_user_id
    GROUP BY ua.user_id
    HAVING COUNT(*) > 0
  ) ranked_users
  WHERE ranked_users.achievement_count > v_user_achievements;
  
  RETURN v_rank;
END;
$$;
-- Grant execute permissions
GRANT EXECUTE ON FUNCTION get_user_psn_rank(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_xbox_rank(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_steam_rank(UUID) TO authenticated;
