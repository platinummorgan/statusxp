-- Fix the RPC function return type to match actual game_title_id column type (BIGINT)
DROP FUNCTION IF EXISTS public.get_most_time_sunk_game(UUID);

CREATE OR REPLACE FUNCTION public.get_most_time_sunk_game(p_user_id UUID)
RETURNS TABLE (
  game_title_id BIGINT,
  achievement_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.game_title_id,
    COUNT(*) AS achievement_count
  FROM public.user_achievements ua
  INNER JOIN public.achievements a ON ua.achievement_id = a.id
  WHERE ua.user_id = p_user_id
  GROUP BY a.game_title_id
  ORDER BY achievement_count DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
