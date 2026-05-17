-- Fix get_sweatiest_platinum_v2 to use V2 achievement schema fields.
-- Previous manual production variant referenced legacy columns (a.tier / a.is_rare)
-- which causes runtime errors and blank Flex Room tiles.

CREATE OR REPLACE FUNCTION public.get_sweatiest_platinum_v2(p_user_id uuid)
RETURNS TABLE(
  platform_id bigint,
  platform_game_id text,
  platform_achievement_id text,
  earned_at timestamp with time zone,
  rarity_global numeric,
  achievement_name text,
  achievement_icon_url text,
  game_name text,
  game_cover_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = 'public, pg_temp'
AS $$
BEGIN
  RETURN QUERY
  SELECT
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name AS achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) AS achievement_icon_url,
    g.name AS game_name,
    g.cover_url AS game_cover_url
  FROM public.user_achievements ua
  INNER JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  INNER JOIN public.games g
    ON g.platform_id = ua.platform_id
   AND g.platform_game_id = ua.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.platform_id IN (1, 2, 5, 9) -- PSN family only
    AND ua.earned_at IS NOT NULL
    AND a.rarity_global IS NOT NULL
    AND (
      a.is_platinum = TRUE
      OR LOWER(COALESCE(a.metadata->>'psn_trophy_type', '')) = 'platinum'
    )
  ORDER BY a.rarity_global ASC, ua.earned_at DESC
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_sweatiest_platinum_v2(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_sweatiest_platinum_v2(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_sweatiest_platinum_v2(uuid) TO service_role;
