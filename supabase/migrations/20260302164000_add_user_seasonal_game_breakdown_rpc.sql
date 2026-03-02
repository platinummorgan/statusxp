-- Seasonal user drilldown RPC:
-- Returns per-game contribution rows for one target user, board, and period.
-- Used by Seasonal Leaderboard user drilldown UI.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_user_seasonal_game_breakdown(
  p_target_user_id uuid,
  p_board_type text DEFAULT 'statusxp',
  p_period_type text DEFAULT 'weekly',
  limit_count integer DEFAULT 200,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  platform_id integer,
  platform_game_id text,
  game_name text,
  cover_url text,
  period_gain bigint,
  earned_count integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH input AS (
  SELECT
    CASE
      WHEN LOWER(COALESCE(p_board_type, 'statusxp')) IN ('statusxp', 'psn', 'xbox', 'steam')
        THEN LOWER(COALESCE(p_board_type, 'statusxp'))
      ELSE 'statusxp'
    END AS board_type,
    CASE
      WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
      ELSE 'weekly'
    END AS period_type
),
period_window AS (
  SELECT
    i.period_type,
    public.get_leaderboard_period_start(i.period_type, now()) AS period_start,
    CASE
      WHEN i.period_type = 'monthly'
        THEN public.get_leaderboard_period_start(i.period_type, now()) + INTERVAL '1 month'
      ELSE public.get_leaderboard_period_start(i.period_type, now()) + INTERVAL '7 days'
    END AS period_end
  FROM input i
),
target_user AS (
  SELECT p.id AS user_id
  FROM public.profiles p
  WHERE p.id = p_target_user_id
    AND (p.show_on_leaderboard = true OR p.id = auth.uid())
),
breakdown_rows AS (
  SELECT
    ua.platform_id,
    ua.platform_game_id,
    (a.base_status_xp * COALESCE(a.rarity_multiplier, 1.0))::numeric AS contribution
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  JOIN target_user tu ON tu.user_id = ua.user_id
  CROSS JOIN input i
  CROSS JOIN period_window w
  WHERE i.board_type = 'statusxp'
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
    AND a.include_in_score = true

  UNION ALL

  SELECT
    ua.platform_id,
    ua.platform_game_id,
    1::numeric AS contribution
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  JOIN target_user tu ON tu.user_id = ua.user_id
  CROSS JOIN input i
  CROSS JOIN period_window w
  WHERE i.board_type = 'psn'
    AND ua.platform_id IN (1, 2, 5, 9)
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
    AND a.is_platinum = true

  UNION ALL

  SELECT
    ua.platform_id,
    ua.platform_game_id,
    COALESCE(a.score_value, 0)::numeric AS contribution
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  JOIN target_user tu ON tu.user_id = ua.user_id
  CROSS JOIN input i
  CROSS JOIN period_window w
  WHERE i.board_type = 'xbox'
    AND ua.platform_id IN (10, 11, 12)
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end

  UNION ALL

  SELECT
    ua.platform_id,
    ua.platform_game_id,
    1::numeric AS contribution
  FROM public.user_achievements ua
  JOIN target_user tu ON tu.user_id = ua.user_id
  CROSS JOIN input i
  CROSS JOIN period_window w
  WHERE i.board_type = 'steam'
    AND ua.platform_id = 4
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
),
grouped AS (
  SELECT
    br.platform_id,
    br.platform_game_id,
    SUM(br.contribution)::bigint AS period_gain,
    COUNT(*)::integer AS earned_count
  FROM breakdown_rows br
  GROUP BY br.platform_id, br.platform_game_id
)
SELECT
  g2.platform_id,
  g2.platform_game_id,
  COALESCE(g.name, g2.platform_game_id)::text AS game_name,
  g.cover_url,
  g2.period_gain,
  g2.earned_count
FROM grouped g2
LEFT JOIN public.games g
  ON g.platform_id = g2.platform_id
 AND g.platform_game_id = g2.platform_game_id
ORDER BY
  g2.period_gain DESC,
  g2.earned_count DESC,
  COALESCE(g.name, g2.platform_game_id) ASC
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;

REVOKE ALL ON FUNCTION public.get_user_seasonal_game_breakdown(uuid, text, text, integer, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_seasonal_game_breakdown(uuid, text, text, integer, integer)
  TO anon, authenticated, service_role;

COMMIT;
