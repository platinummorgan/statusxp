-- Migration: Create function to get achievement counts by platform with JOIN
-- Returns platform_id, platform_code, platform_name, and count for current user

CREATE OR REPLACE FUNCTION get_platform_achievement_counts(p_user_id uuid)
RETURNS TABLE (
  platform_id bigint,
  platform_code text,
  platform_name text,
  earned_rows int
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id as platform_id,
    p.code as platform_code,
    p.name as platform_name,
    count(*)::int as earned_rows
  FROM user_achievements ua
  JOIN platforms p ON p.id = ua.platform_id
  WHERE ua.user_id = p_user_id
  GROUP BY p.id, p.code, p.name
  ORDER BY p.id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_platform_achievement_counts(uuid) TO authenticated;

COMMENT ON FUNCTION get_platform_achievement_counts IS 
  'Returns achievement counts grouped by platform for a user. Joins platforms table to return platform_code and platform_name directly instead of requiring frontend mapping.';
