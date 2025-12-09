-- Create a function to get last trophy dates for all user games
CREATE OR REPLACE FUNCTION get_last_trophy_dates(p_user_id uuid)
RETURNS TABLE (
  game_title_id bigint,
  last_earned_at timestamptz
) 
LANGUAGE sql
SECURITY DEFINER
AS $$
  SELECT 
    a.game_title_id,
    MAX(ua.earned_at) as last_earned_at
  FROM user_achievements ua
  JOIN achievements a ON a.id = ua.achievement_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
  GROUP BY a.game_title_id;
$$;
