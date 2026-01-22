-- Fix the calculate_user_game_statusxp function to use base_status_xp
DROP FUNCTION IF EXISTS calculate_user_game_statusxp() CASCADE;

CREATE OR REPLACE FUNCTION calculate_user_game_statusxp()
RETURNS void AS $$
BEGIN
  -- Calculate raw StatusXP (sum of base_status_xp for all earned achievements)
  WITH game_statusxp AS (
    SELECT 
      ug.id as user_game_id,
      COALESCE(SUM(a.base_status_xp), 0) as raw_xp,
      COUNT(*) FILTER (WHERE a.is_dlc = false AND ua.id IS NOT NULL) as base_unlocked,
      COUNT(*) FILTER (WHERE a.is_dlc = false) as base_total
    FROM public.user_games ug
    CROSS JOIN LATERAL (
      SELECT code as platform_code FROM public.platforms WHERE id = ug.platform_id
    ) p
    LEFT JOIN public.achievements a ON a.game_title_id = ug.game_title_id 
      AND (
        (a.platform = 'psn' AND p.platform_code IN ('PS3', 'PS4', 'PS5', 'PSVITA')) OR
        (a.platform = 'xbox' AND p.platform_code LIKE '%XBOX%') OR
        (a.platform = 'steam' AND p.platform_code = 'Steam')
      )
    LEFT JOIN public.user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
    GROUP BY ug.id
  )
  UPDATE public.user_games ug
  SET 
    statusxp_raw = gs.raw_xp::integer,
    base_completed = (gs.base_total > 0 AND gs.base_unlocked = gs.base_total),
    statusxp_effective = (gs.raw_xp * stack_multiplier)::integer
  FROM game_statusxp gs
  WHERE ug.id = gs.user_game_id;
END;
$$ LANGUAGE plpgsql;

-- Now run the function to recalculate all games
SELECT calculate_user_game_statusxp();

-- Verify the results for 11-11
SELECT
  gt.name as game_name,
  ug.statusxp_raw,
  ug.statusxp_effective,
  ug.stack_multiplier
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE gt.name ILIKE '%11-11%'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
