-- Optional: Create RPC function for better platinum leaderboard performance
-- Run this in Supabase SQL Editor for optimized queries

CREATE OR REPLACE FUNCTION get_platinum_leaderboard(limit_count INT DEFAULT 100)
RETURNS TABLE (
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  score BIGINT,
  games_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id as user_id,
    COALESCE(p.display_name, p.psn_online_id, 'Unknown') as display_name,
    p.avatar_url,
    COUNT(*)::BIGINT as score,
    COUNT(DISTINCT a.game_title_id)::BIGINT as games_count
  FROM profiles p
  JOIN user_achievements ua ON p.id = ua.user_id
  JOIN achievements a ON ua.achievement_id = a.id
  WHERE a.platform = 'psn' AND a.psn_trophy_type = 'platinum'
  GROUP BY p.id, p.display_name, p.psn_online_id, p.avatar_url
  ORDER BY score DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Grant access to authenticated users
GRANT EXECUTE ON FUNCTION get_platinum_leaderboard TO authenticated;
GRANT EXECUTE ON FUNCTION get_platinum_leaderboard TO anon;

-- Test the function
SELECT * FROM get_platinum_leaderboard(10);
