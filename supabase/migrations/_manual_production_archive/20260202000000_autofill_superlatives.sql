-- Enhanced superlative suggestions function with logic for all 12 categories
CREATE OR REPLACE FUNCTION get_superlative_suggestions_v3(
  p_user_id UUID,
  p_category TEXT
)
RETURNS TABLE (
  platform_id BIGINT,
  platform_game_id TEXT,
  platform_achievement_id TEXT,
  earned_at TIMESTAMPTZ,
  score NUMERIC
) AS $$
BEGIN
  -- Category: hardest - lowest rarity achievements (hardest to get)
  IF p_category = 'hardest' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global > 0
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Category: easiest - highest rarity achievements (most common)
  ELSIF p_category = 'easiest' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
    ORDER BY a.rarity_global DESC
    LIMIT 1;
    
  -- Category: aggravating - achievements with names suggesting difficulty/frustration
  ELSIF p_category = 'aggravating' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 5.0
      AND (
        a.name ILIKE '%difficult%' 
        OR a.name ILIKE '%hard%'
        OR a.name ILIKE '%master%'
        OR a.name ILIKE '%challenge%'
        OR a.description ILIKE '%without dying%'
        OR a.description ILIKE '%no damage%'
      )
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Category: rage_inducing - very rare + challenging description
  ELSIF p_category = 'rage_inducing' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 3.0
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Category: biggest_grind - game with most achievements unlocked
  ELSIF p_category = 'biggest_grind' THEN
    RETURN QUERY
    WITH game_achievement_counts AS (
      SELECT 
        ua.platform_id,
        ua.platform_game_id,
        COUNT(*) as achievement_count,
        MAX(ua.earned_at) as latest_earned
      FROM user_achievements ua
      WHERE ua.user_id = p_user_id
      GROUP BY ua.platform_id, ua.platform_game_id
      ORDER BY achievement_count DESC
      LIMIT 1
    )
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      gac.achievement_count::NUMERIC as score
    FROM user_achievements ua
    INNER JOIN game_achievement_counts gac ON
      gac.platform_id = ua.platform_id
      AND gac.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND ua.earned_at = gac.latest_earned
    LIMIT 1;
    
  -- Category: most_time - same as biggest_grind (most achievements = most time)
  ELSIF p_category = 'most_time' THEN
    RETURN QUERY
    WITH game_achievement_counts AS (
      SELECT 
        ua.platform_id,
        ua.platform_game_id,
        COUNT(*) as achievement_count,
        MAX(ua.earned_at) as latest_earned
      FROM user_achievements ua
      WHERE ua.user_id = p_user_id
      GROUP BY ua.platform_id, ua.platform_game_id
      ORDER BY achievement_count DESC
      LIMIT 1
    )
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      gac.achievement_count::NUMERIC as score
    FROM user_achievements ua
    INNER JOIN game_achievement_counts gac ON
      gac.platform_id = ua.platform_id
      AND gac.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND ua.earned_at = gac.latest_earned
    LIMIT 1;
    
  -- Category: rng_nightmare - ultra rare (< 1%)
  ELSIF p_category = 'rng_nightmare' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 1.0
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Category: never_again - rare achievement from a challenging game
  ELSIF p_category = 'never_again' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 2.0
    ORDER BY a.rarity_global ASC, ua.earned_at DESC
    LIMIT 1;
    
  -- Category: most_proud - platinum trophies (if any), else rarest achievement
  ELSIF p_category = 'most_proud' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND (
        a.metadata->>'psn_trophy_type' = 'platinum'
        OR a.rarity_global < 5.0
      )
    ORDER BY 
      (a.metadata->>'psn_trophy_type' = 'platinum') DESC,
      a.rarity_global ASC
    LIMIT 1;
    
  -- Category: clutch - recent rare achievement (clutch moment)
  ELSIF p_category = 'clutch' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 10.0
    ORDER BY ua.earned_at DESC
    LIMIT 1;
    
  -- Category: cozy_comfort - common/easy achievement (comfort game)
  ELSIF p_category = 'cozy_comfort' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global > 50.0
    ORDER BY a.rarity_global DESC, ua.earned_at DESC
    LIMIT 1;
    
  -- Category: hidden_gem - rare game (fewer people have played it)
  ELSIF p_category = 'hidden_gem' THEN
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
      AND a.rarity_global < 15.0
      AND a.rarity_global > 1.0
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  -- Default: return rarest achievement
  ELSE
    RETURN QUERY
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      ua.platform_achievement_id,
      ua.earned_at,
      a.rarity_global as score
    FROM user_achievements ua
    INNER JOIN achievements a ON 
      a.platform_id = ua.platform_id 
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    WHERE ua.user_id = p_user_id
      AND a.rarity_global IS NOT NULL
    ORDER BY a.rarity_global ASC
    LIMIT 1;
    
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_superlative_suggestions_v3(UUID, TEXT) TO authenticated;

COMMENT ON FUNCTION get_superlative_suggestions_v3(UUID, TEXT) IS 'Get smart suggestions for superlative categories with intelligent logic for each of the 12 types';
