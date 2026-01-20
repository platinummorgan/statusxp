-- Update get_user_grouped_games function to include proxied_cover_url
-- This function groups games by achievement similarity and now returns proxied cover URLs

-- Drop existing function first (required when changing return type)
DROP FUNCTION IF EXISTS get_user_grouped_games(UUID);

CREATE OR REPLACE FUNCTION get_user_grouped_games(p_user_id UUID)
RETURNS TABLE (
  name TEXT,
  cover_url TEXT,
  proxied_cover_url TEXT,
  platforms JSONB
) AS $$
BEGIN
  RETURN QUERY
  WITH user_games_with_details AS (
    SELECT 
      ug.id,
      ug.game_title_id,
      gt.name,
      gt.cover_url,
      gt.proxied_cover_url,
      p.code as platform_code,
      ug.completion_percent,
      ug.earned_trophies,
      ug.total_trophies,
      ug.bronze_trophies,
      ug.silver_trophies,
      ug.gold_trophies,
      ug.platinum_trophies,
      ug.last_played_at,
      ug.last_trophy_earned_at,
      COALESCE(
        (SELECT SUM(ua.statusxp_points) 
         FROM user_achievements ua 
         INNER JOIN achievements a ON ua.achievement_id = a.id
         WHERE ua.user_id = ug.user_id 
         AND a.game_title_id = ug.game_title_id),
        0
      ) as statusxp
    FROM user_games ug
    INNER JOIN game_titles gt ON ug.game_title_id = gt.id
    INNER JOIN platforms p ON ug.platform_id = p.id
    WHERE ug.user_id = p_user_id
  ),
  grouped_games AS (
    SELECT 
      user_games_with_details.name,
      MAX(user_games_with_details.cover_url) as cover_url,
      MAX(user_games_with_details.proxied_cover_url) as proxied_cover_url,
      jsonb_agg(
        jsonb_build_object(
          'code', user_games_with_details.platform_code,
          'game_title_id', user_games_with_details.game_title_id,
          'completion', user_games_with_details.completion_percent,
          'earned_trophies', user_games_with_details.earned_trophies,
          'total_trophies', user_games_with_details.total_trophies,
          'bronze_trophies', user_games_with_details.bronze_trophies,
          'silver_trophies', user_games_with_details.silver_trophies,
          'gold_trophies', user_games_with_details.gold_trophies,
          'platinum_trophies', user_games_with_details.platinum_trophies,
          'statusxp', user_games_with_details.statusxp,
          'last_played_at', user_games_with_details.last_played_at,
          'last_trophy_earned_at', user_games_with_details.last_trophy_earned_at
        )
      ) as platforms
    FROM user_games_with_details
    GROUP BY user_games_with_details.name
  )
  SELECT 
    g.name,
    g.cover_url,
    g.proxied_cover_url,
    g.platforms
  FROM grouped_games g;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_grouped_games(UUID) TO authenticated;
