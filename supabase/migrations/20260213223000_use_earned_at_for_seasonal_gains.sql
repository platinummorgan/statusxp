-- Seasonal leaderboards: compute weekly/monthly gains by earned_at (not by sync/snapshot deltas).
-- This prevents "banked sync" spikes from users who haven't synced recently.
--
-- Notes:
-- - Weekly/monthly boundaries come from get_leaderboard_period_start(), including overrides.
-- - Gains only count once the unlocks exist in our DB (i.e., after a sync imports them).
-- - This changes period_gain semantics to "earned within the period window", not "delta since first in-period snapshot".

BEGIN;

-- ============================================================
-- StatusXP (all platforms)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_statusxp_period_leaderboard(
  p_period_type text DEFAULT 'weekly',
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  display_name text,
  avatar_url text,
  period_gain bigint,
  current_total bigint,
  baseline_total bigint,
  total_game_entries integer,
  current_rank bigint
)
LANGUAGE sql
STABLE
AS $$
WITH bounds AS (
  SELECT
    CASE
      WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
      ELSE 'weekly'
    END AS period_type,
    public.get_leaderboard_period_start(p_period_type, now()) AS period_start
),
period_window AS (
  SELECT
    b.period_type,
    b.period_start,
    CASE
      WHEN b.period_type = 'monthly' THEN b.period_start + INTERVAL '1 month'
      ELSE b.period_start + INTERVAL '7 days'
    END AS period_end
  FROM bounds b
),
current_scores AS (
  SELECT
    lc.user_id,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_online_id
        WHEN 'xbox' THEN p.xbox_gamertag
        WHEN 'steam' THEN p.steam_display_name
      END,
      p.psn_online_id,
      p.xbox_gamertag,
      p.steam_display_name,
      p.display_name,
      p.username,
      'Player'::text
    ) AS display_name,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_avatar_url
        WHEN 'xbox' THEN p.xbox_avatar_url
        WHEN 'steam' THEN p.steam_avatar_url
      END,
      p.avatar_url
    ) AS avatar_url,
    lc.total_statusxp::bigint AS current_total,
    lc.total_game_entries
  FROM public.leaderboard_cache lc
  JOIN public.profiles p ON p.id = lc.user_id
  WHERE p.show_on_leaderboard = true
    AND lc.total_statusxp > 0
),
earned AS (
  SELECT
    ua.user_id,
    SUM((a.base_status_xp) * COALESCE(a.rarity_multiplier, 1.0))::bigint AS gain
  FROM public.user_achievements ua
  JOIN public.achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN period_window w
  WHERE ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
    AND a.include_in_score = true
  GROUP BY ua.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    COALESCE(e.gain, 0)::bigint AS period_gain,
    cs.current_total,
    GREATEST(cs.current_total - COALESCE(e.gain, 0), 0)::bigint AS baseline_total,
    cs.total_game_entries,
    ROW_NUMBER() OVER (
      ORDER BY
        COALESCE(e.gain, 0) DESC,
        cs.current_total DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN earned e ON e.user_id = cs.user_id
)
SELECT
  r.user_id,
  r.display_name,
  r.avatar_url,
  r.period_gain,
  r.current_total,
  r.baseline_total,
  r.total_game_entries,
  r.current_rank
FROM ranked r
ORDER BY r.current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;

-- ============================================================
-- PSN (Platinums)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_psn_period_leaderboard(
  p_period_type text DEFAULT 'weekly',
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  display_name text,
  avatar_url text,
  period_gain bigint,
  platinum_count bigint,
  gold_count bigint,
  silver_count bigint,
  bronze_count bigint,
  total_trophies bigint,
  total_games bigint,
  current_rank bigint
)
LANGUAGE sql
STABLE
AS $$
WITH bounds AS (
  SELECT
    CASE
      WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
      ELSE 'weekly'
    END AS period_type,
    public.get_leaderboard_period_start(p_period_type, now()) AS period_start
),
period_window AS (
  SELECT
    b.period_type,
    b.period_start,
    CASE
      WHEN b.period_type = 'monthly' THEN b.period_start + INTERVAL '1 month'
      ELSE b.period_start + INTERVAL '7 days'
    END AS period_end
  FROM bounds b
),
current_scores AS (
  SELECT
    plc.user_id,
    plc.display_name,
    plc.avatar_url,
    plc.platinum_count::bigint AS platinum_count,
    plc.gold_count::bigint AS gold_count,
    plc.silver_count::bigint AS silver_count,
    plc.bronze_count::bigint AS bronze_count,
    plc.total_trophies::bigint AS total_trophies,
    plc.total_games::bigint AS total_games
  FROM public.psn_leaderboard_cache plc
),
earned AS (
  SELECT
    ua.user_id,
    COUNT(*) FILTER (WHERE a.is_platinum = true)::bigint AS gain
  FROM public.user_achievements ua
  JOIN public.achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN period_window w
  WHERE ua.platform_id IN (1, 2, 5, 9)
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
  GROUP BY ua.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    COALESCE(e.gain, 0)::bigint AS period_gain,
    cs.platinum_count,
    cs.gold_count,
    cs.silver_count,
    cs.bronze_count,
    cs.total_trophies,
    cs.total_games,
    ROW_NUMBER() OVER (
      ORDER BY
        COALESCE(e.gain, 0) DESC,
        cs.platinum_count DESC,
        cs.gold_count DESC,
        cs.silver_count DESC,
        cs.bronze_count DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN earned e ON e.user_id = cs.user_id
)
SELECT
  r.user_id,
  r.display_name,
  r.avatar_url,
  r.period_gain,
  r.platinum_count,
  r.gold_count,
  r.silver_count,
  r.bronze_count,
  r.total_trophies,
  r.total_games,
  r.current_rank
FROM ranked r
ORDER BY r.current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;

-- ============================================================
-- Xbox (Gamerscore)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_xbox_period_leaderboard(
  p_period_type text DEFAULT 'weekly',
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  display_name text,
  avatar_url text,
  period_gain bigint,
  gamerscore bigint,
  potential_gamerscore bigint,
  achievement_count bigint,
  total_games bigint,
  current_rank bigint
)
LANGUAGE sql
STABLE
AS $$
WITH bounds AS (
  SELECT
    CASE
      WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
      ELSE 'weekly'
    END AS period_type,
    public.get_leaderboard_period_start(p_period_type, now()) AS period_start
),
period_window AS (
  SELECT
    b.period_type,
    b.period_start,
    CASE
      WHEN b.period_type = 'monthly' THEN b.period_start + INTERVAL '1 month'
      ELSE b.period_start + INTERVAL '7 days'
    END AS period_end
  FROM bounds b
),
current_scores AS (
  SELECT
    xlc.user_id,
    xlc.display_name,
    xlc.avatar_url,
    xlc.gamerscore::bigint AS gamerscore,
    xlc.potential_gamerscore::bigint AS potential_gamerscore,
    xlc.achievement_count::bigint AS achievement_count,
    xlc.total_games::bigint AS total_games
  FROM public.xbox_leaderboard_cache xlc
),
earned AS (
  SELECT
    ua.user_id,
    SUM(COALESCE(a.score_value, 0))::bigint AS gain
  FROM public.user_achievements ua
  JOIN public.achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN period_window w
  WHERE ua.platform_id IN (10, 11, 12)
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
  GROUP BY ua.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    COALESCE(e.gain, 0)::bigint AS period_gain,
    cs.gamerscore,
    cs.potential_gamerscore,
    cs.achievement_count,
    cs.total_games,
    ROW_NUMBER() OVER (
      ORDER BY
        COALESCE(e.gain, 0) DESC,
        cs.gamerscore DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN earned e ON e.user_id = cs.user_id
)
SELECT
  r.user_id,
  r.display_name,
  r.avatar_url,
  r.period_gain,
  r.gamerscore,
  r.potential_gamerscore,
  r.achievement_count,
  r.total_games,
  r.current_rank
FROM ranked r
ORDER BY r.current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;

-- ============================================================
-- Steam (Achievements)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_steam_period_leaderboard(
  p_period_type text DEFAULT 'weekly',
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  display_name text,
  avatar_url text,
  period_gain bigint,
  achievement_count bigint,
  potential_achievements bigint,
  total_games bigint,
  current_rank bigint
)
LANGUAGE sql
STABLE
AS $$
WITH bounds AS (
  SELECT
    CASE
      WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
      ELSE 'weekly'
    END AS period_type,
    public.get_leaderboard_period_start(p_period_type, now()) AS period_start
),
period_window AS (
  SELECT
    b.period_type,
    b.period_start,
    CASE
      WHEN b.period_type = 'monthly' THEN b.period_start + INTERVAL '1 month'
      ELSE b.period_start + INTERVAL '7 days'
    END AS period_end
  FROM bounds b
),
current_scores AS (
  SELECT
    slc.user_id,
    slc.display_name,
    slc.avatar_url,
    slc.achievement_count::bigint AS achievement_count,
    slc.potential_achievements::bigint AS potential_achievements,
    slc.total_games::bigint AS total_games
  FROM public.steam_leaderboard_cache slc
),
earned AS (
  SELECT
    ua.user_id,
    COUNT(*)::bigint AS gain
  FROM public.user_achievements ua
  CROSS JOIN period_window w
  WHERE ua.platform_id = 4
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
  GROUP BY ua.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    COALESCE(e.gain, 0)::bigint AS period_gain,
    cs.achievement_count,
    cs.potential_achievements,
    cs.total_games,
    ROW_NUMBER() OVER (
      ORDER BY
        COALESCE(e.gain, 0) DESC,
        cs.achievement_count DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN earned e ON e.user_id = cs.user_id
)
SELECT
  r.user_id,
  r.display_name,
  r.avatar_url,
  r.period_gain,
  r.achievement_count,
  r.potential_achievements,
  r.total_games,
  r.current_rank
FROM ranked r
ORDER BY r.current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;

COMMIT;
