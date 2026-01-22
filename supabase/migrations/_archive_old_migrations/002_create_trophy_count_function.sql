-- Function to get trophy counts by tier for a user
CREATE OR REPLACE FUNCTION get_user_trophy_counts(user_id_param UUID)
RETURNS TABLE (tier TEXT, count BIGINT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.tier,
    COUNT(*)::BIGINT as count
  FROM user_trophies ut
  INNER JOIN trophies t ON ut.trophy_id = t.id
  WHERE ut.user_id = user_id_param
    AND ut.earned_at IS NOT NULL
  GROUP BY t.tier;
END;
$$;
