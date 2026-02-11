-- Fix seasonal leaderboard baseline selection.
-- Uses the last snapshot before period start when available, otherwise first in-period snapshot.

BEGIN;

CREATE OR REPLACE FUNCTION "public"."get_statusxp_period_leaderboard"(
  "p_period_type" "text" DEFAULT 'weekly'::"text",
  "limit_count" integer DEFAULT 100,
  "offset_count" integer DEFAULT 0
) RETURNS TABLE(
  "user_id" "uuid",
  "display_name" "text",
  "avatar_url" "text",
  "period_gain" bigint,
  "current_total" bigint,
  "baseline_total" bigint,
  "total_game_entries" integer,
  "current_rank" bigint
)
LANGUAGE "sql"
STABLE
AS $$
WITH bounds AS (
  SELECT CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly'
      THEN (date_trunc('month', timezone('UTC', now())) AT TIME ZONE 'UTC')
    ELSE (date_trunc('week', timezone('UTC', now())) AT TIME ZONE 'UTC')
  END AS period_start
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
baseline_before AS (
  SELECT DISTINCT ON (lh.user_id)
    lh.user_id,
    lh.total_statusxp::bigint AS baseline_total
  FROM public.leaderboard_history lh
  CROSS JOIN bounds b
  WHERE lh.snapshot_at < b.period_start
  ORDER BY lh.user_id, lh.snapshot_at DESC
),
baseline_in_period AS (
  SELECT DISTINCT ON (lh.user_id)
    lh.user_id,
    lh.total_statusxp::bigint AS baseline_total
  FROM public.leaderboard_history lh
  CROSS JOIN bounds b
  WHERE lh.snapshot_at >= b.period_start
  ORDER BY lh.user_id, lh.snapshot_at ASC
),
baseline_scores AS (
  SELECT
    cs.user_id,
    COALESCE(bb.baseline_total, bip.baseline_total) AS baseline_total
  FROM current_scores cs
  LEFT JOIN baseline_before bb ON bb.user_id = cs.user_id
  LEFT JOIN baseline_in_period bip ON bip.user_id = cs.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    GREATEST(cs.current_total - COALESCE(bs.baseline_total, cs.current_total), 0)::bigint AS period_gain,
    cs.current_total,
    COALESCE(bs.baseline_total, cs.current_total) AS baseline_total,
    cs.total_game_entries,
    ROW_NUMBER() OVER (
      ORDER BY
        GREATEST(cs.current_total - COALESCE(bs.baseline_total, cs.current_total), 0) DESC,
        cs.current_total DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN baseline_scores bs ON bs.user_id = cs.user_id
)
SELECT
  user_id,
  display_name,
  avatar_url,
  period_gain,
  current_total,
  baseline_total,
  total_game_entries,
  current_rank
FROM ranked
ORDER BY current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;


CREATE OR REPLACE FUNCTION "public"."get_psn_period_leaderboard"(
  "p_period_type" "text" DEFAULT 'weekly'::"text",
  "limit_count" integer DEFAULT 100,
  "offset_count" integer DEFAULT 0
) RETURNS TABLE(
  "user_id" "uuid",
  "display_name" "text",
  "avatar_url" "text",
  "period_gain" bigint,
  "platinum_count" bigint,
  "gold_count" bigint,
  "silver_count" bigint,
  "bronze_count" bigint,
  "total_trophies" bigint,
  "total_games" bigint,
  "current_rank" bigint
)
LANGUAGE "sql"
STABLE
AS $$
WITH bounds AS (
  SELECT CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly'
      THEN (date_trunc('month', timezone('UTC', now())) AT TIME ZONE 'UTC')
    ELSE (date_trunc('week', timezone('UTC', now())) AT TIME ZONE 'UTC')
  END AS period_start
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
baseline_before AS (
  SELECT DISTINCT ON (ph.user_id)
    ph.user_id,
    ph.platinum_count::bigint AS baseline_platinum
  FROM public.psn_leaderboard_history ph
  CROSS JOIN bounds b
  WHERE ph.snapshot_at < b.period_start
  ORDER BY ph.user_id, ph.snapshot_at DESC
),
baseline_in_period AS (
  SELECT DISTINCT ON (ph.user_id)
    ph.user_id,
    ph.platinum_count::bigint AS baseline_platinum
  FROM public.psn_leaderboard_history ph
  CROSS JOIN bounds b
  WHERE ph.snapshot_at >= b.period_start
  ORDER BY ph.user_id, ph.snapshot_at ASC
),
baseline_scores AS (
  SELECT
    cs.user_id,
    COALESCE(bb.baseline_platinum, bip.baseline_platinum) AS baseline_platinum
  FROM current_scores cs
  LEFT JOIN baseline_before bb ON bb.user_id = cs.user_id
  LEFT JOIN baseline_in_period bip ON bip.user_id = cs.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    GREATEST(cs.platinum_count - COALESCE(bs.baseline_platinum, cs.platinum_count), 0)::bigint AS period_gain,
    cs.platinum_count,
    cs.gold_count,
    cs.silver_count,
    cs.bronze_count,
    cs.total_trophies,
    cs.total_games,
    ROW_NUMBER() OVER (
      ORDER BY
        GREATEST(cs.platinum_count - COALESCE(bs.baseline_platinum, cs.platinum_count), 0) DESC,
        cs.platinum_count DESC,
        cs.gold_count DESC,
        cs.silver_count DESC,
        cs.bronze_count DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN baseline_scores bs ON bs.user_id = cs.user_id
)
SELECT
  user_id,
  display_name,
  avatar_url,
  period_gain,
  platinum_count,
  gold_count,
  silver_count,
  bronze_count,
  total_trophies,
  total_games,
  current_rank
FROM ranked
ORDER BY current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;


CREATE OR REPLACE FUNCTION "public"."get_xbox_period_leaderboard"(
  "p_period_type" "text" DEFAULT 'weekly'::"text",
  "limit_count" integer DEFAULT 100,
  "offset_count" integer DEFAULT 0
) RETURNS TABLE(
  "user_id" "uuid",
  "display_name" "text",
  "avatar_url" "text",
  "period_gain" bigint,
  "gamerscore" bigint,
  "potential_gamerscore" bigint,
  "achievement_count" bigint,
  "total_games" bigint,
  "current_rank" bigint
)
LANGUAGE "sql"
STABLE
AS $$
WITH bounds AS (
  SELECT CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly'
      THEN (date_trunc('month', timezone('UTC', now())) AT TIME ZONE 'UTC')
    ELSE (date_trunc('week', timezone('UTC', now())) AT TIME ZONE 'UTC')
  END AS period_start
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
baseline_before AS (
  SELECT DISTINCT ON (xh.user_id)
    xh.user_id,
    xh.gamerscore::bigint AS baseline_gamerscore
  FROM public.xbox_leaderboard_history xh
  CROSS JOIN bounds b
  WHERE xh.snapshot_at < b.period_start
  ORDER BY xh.user_id, xh.snapshot_at DESC
),
baseline_in_period AS (
  SELECT DISTINCT ON (xh.user_id)
    xh.user_id,
    xh.gamerscore::bigint AS baseline_gamerscore
  FROM public.xbox_leaderboard_history xh
  CROSS JOIN bounds b
  WHERE xh.snapshot_at >= b.period_start
  ORDER BY xh.user_id, xh.snapshot_at ASC
),
baseline_scores AS (
  SELECT
    cs.user_id,
    COALESCE(bb.baseline_gamerscore, bip.baseline_gamerscore) AS baseline_gamerscore
  FROM current_scores cs
  LEFT JOIN baseline_before bb ON bb.user_id = cs.user_id
  LEFT JOIN baseline_in_period bip ON bip.user_id = cs.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    GREATEST(cs.gamerscore - COALESCE(bs.baseline_gamerscore, cs.gamerscore), 0)::bigint AS period_gain,
    cs.gamerscore,
    cs.potential_gamerscore,
    cs.achievement_count,
    cs.total_games,
    ROW_NUMBER() OVER (
      ORDER BY
        GREATEST(cs.gamerscore - COALESCE(bs.baseline_gamerscore, cs.gamerscore), 0) DESC,
        cs.gamerscore DESC,
        cs.achievement_count DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN baseline_scores bs ON bs.user_id = cs.user_id
)
SELECT
  user_id,
  display_name,
  avatar_url,
  period_gain,
  gamerscore,
  potential_gamerscore,
  achievement_count,
  total_games,
  current_rank
FROM ranked
ORDER BY current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;


CREATE OR REPLACE FUNCTION "public"."get_steam_period_leaderboard"(
  "p_period_type" "text" DEFAULT 'weekly'::"text",
  "limit_count" integer DEFAULT 100,
  "offset_count" integer DEFAULT 0
) RETURNS TABLE(
  "user_id" "uuid",
  "display_name" "text",
  "avatar_url" "text",
  "period_gain" bigint,
  "achievement_count" bigint,
  "potential_achievements" bigint,
  "total_games" bigint,
  "current_rank" bigint
)
LANGUAGE "sql"
STABLE
AS $$
WITH bounds AS (
  SELECT CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly'
      THEN (date_trunc('month', timezone('UTC', now())) AT TIME ZONE 'UTC')
    ELSE (date_trunc('week', timezone('UTC', now())) AT TIME ZONE 'UTC')
  END AS period_start
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
baseline_before AS (
  SELECT DISTINCT ON (sh.user_id)
    sh.user_id,
    sh.achievement_count::bigint AS baseline_achievements
  FROM public.steam_leaderboard_history sh
  CROSS JOIN bounds b
  WHERE sh.snapshot_at < b.period_start
  ORDER BY sh.user_id, sh.snapshot_at DESC
),
baseline_in_period AS (
  SELECT DISTINCT ON (sh.user_id)
    sh.user_id,
    sh.achievement_count::bigint AS baseline_achievements
  FROM public.steam_leaderboard_history sh
  CROSS JOIN bounds b
  WHERE sh.snapshot_at >= b.period_start
  ORDER BY sh.user_id, sh.snapshot_at ASC
),
baseline_scores AS (
  SELECT
    cs.user_id,
    COALESCE(bb.baseline_achievements, bip.baseline_achievements) AS baseline_achievements
  FROM current_scores cs
  LEFT JOIN baseline_before bb ON bb.user_id = cs.user_id
  LEFT JOIN baseline_in_period bip ON bip.user_id = cs.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    GREATEST(cs.achievement_count - COALESCE(bs.baseline_achievements, cs.achievement_count), 0)::bigint AS period_gain,
    cs.achievement_count,
    cs.potential_achievements,
    cs.total_games,
    ROW_NUMBER() OVER (
      ORDER BY
        GREATEST(cs.achievement_count - COALESCE(bs.baseline_achievements, cs.achievement_count), 0) DESC,
        cs.achievement_count DESC,
        cs.total_games DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN baseline_scores bs ON bs.user_id = cs.user_id
)
SELECT
  user_id,
  display_name,
  avatar_url,
  period_gain,
  achievement_count,
  potential_achievements,
  total_games,
  current_rank
FROM ranked
ORDER BY current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$$;

COMMIT;

