-- Hide weekly Hall of Fame periods prior to the active weekly reset floor.
-- This removes pre-reset weekly records (e.g., last week's winner) from Hall of Fame and spotlight.

BEGIN;

CREATE OR REPLACE FUNCTION "public"."get_leaderboard_hall_of_fame"(
  "p_period_type" "text" DEFAULT 'weekly'::"text",
  "p_leaderboard_type" "text" DEFAULT NULL::"text",
  "limit_count" integer DEFAULT 100
) RETURNS TABLE(
  "leaderboard_type" "text",
  "period_type" "text",
  "period_start" timestamp with time zone,
  "period_end" timestamp with time zone,
  "winner_user_id" "uuid",
  "winner_display_name" "text",
  "winner_avatar_url" "text",
  "winner_gain" bigint,
  "winner_current_score" bigint
)
LANGUAGE "sql"
STABLE
AS $$
WITH settings AS (
  SELECT LOWER(COALESCE(p_period_type, 'weekly')) AS period_type
),
current_bounds AS (
  SELECT
    s.period_type,
    public.get_leaderboard_period_start(s.period_type, now()) AS current_period_start
  FROM settings s
),
reset_floor AS (
  SELECT MAX(spo.start_at) AS weekly_floor
  FROM public.seasonal_period_overrides spo
  WHERE spo.period_type = 'weekly'
),
normalized AS (
  SELECT
    'statusxp'::text AS leaderboard_type,
    lh.user_id,
    lh.snapshot_at,
    lh.total_statusxp::bigint AS metric_value,
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
    ) AS avatar_url
  FROM public.leaderboard_history lh
  JOIN public.profiles p ON p.id = lh.user_id
  WHERE p.show_on_leaderboard = true

  UNION ALL

  SELECT
    'psn'::text AS leaderboard_type,
    ph.user_id,
    ph.snapshot_at,
    ph.platinum_count::bigint AS metric_value,
    COALESCE(p.psn_online_id, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.psn_avatar_url, p.avatar_url) AS avatar_url
  FROM public.psn_leaderboard_history ph
  JOIN public.profiles p ON p.id = ph.user_id
  WHERE p.show_on_leaderboard = true

  UNION ALL

  SELECT
    'xbox'::text AS leaderboard_type,
    xh.user_id,
    xh.snapshot_at,
    xh.gamerscore::bigint AS metric_value,
    COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.xbox_avatar_url, p.avatar_url) AS avatar_url
  FROM public.xbox_leaderboard_history xh
  JOIN public.profiles p ON p.id = xh.user_id
  WHERE p.show_on_leaderboard = true

  UNION ALL

  SELECT
    'steam'::text AS leaderboard_type,
    sh.user_id,
    sh.snapshot_at,
    sh.achievement_count::bigint AS metric_value,
    COALESCE(p.steam_display_name, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.steam_avatar_url, p.avatar_url) AS avatar_url
  FROM public.steam_leaderboard_history sh
  JOIN public.profiles p ON p.id = sh.user_id
  WHERE p.show_on_leaderboard = true
),
bucketed AS (
  SELECT
    n.leaderboard_type,
    cb.period_type,
    CASE
      WHEN cb.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', n.snapshot_at)) AT TIME ZONE 'UTC')
      ELSE public.get_leaderboard_period_start('weekly', n.snapshot_at)
    END AS period_start,
    n.user_id,
    n.snapshot_at,
    n.metric_value,
    n.display_name,
    n.avatar_url
  FROM normalized n
  CROSS JOIN current_bounds cb
),
closed_period_rows AS (
  SELECT b.*
  FROM bucketed b
  JOIN current_bounds cb ON TRUE
  LEFT JOIN reset_floor rf ON TRUE
  WHERE b.period_start < cb.current_period_start
    AND (
      cb.period_type <> 'weekly'
      OR b.period_start >= COALESCE(rf.weekly_floor, '-infinity'::timestamptz)
    )
    AND (
      p_leaderboard_type IS NULL
      OR p_leaderboard_type = ''
      OR b.leaderboard_type = LOWER(p_leaderboard_type)
    )
),
period_user_scores AS (
  SELECT
    x.leaderboard_type,
    x.period_type,
    x.period_start,
    x.user_id,
    MAX(CASE WHEN x.rn_asc = 1 THEN x.metric_value END) AS baseline_value,
    MAX(CASE WHEN x.rn_desc = 1 THEN x.metric_value END) AS current_value,
    MAX(CASE WHEN x.rn_desc = 1 THEN x.display_name END) AS display_name,
    MAX(CASE WHEN x.rn_desc = 1 THEN x.avatar_url END) AS avatar_url
  FROM (
    SELECT
      cpr.*,
      ROW_NUMBER() OVER (
        PARTITION BY cpr.leaderboard_type, cpr.period_start, cpr.user_id
        ORDER BY cpr.snapshot_at ASC
      ) AS rn_asc,
      ROW_NUMBER() OVER (
        PARTITION BY cpr.leaderboard_type, cpr.period_start, cpr.user_id
        ORDER BY cpr.snapshot_at DESC
      ) AS rn_desc
    FROM closed_period_rows cpr
  ) x
  GROUP BY x.leaderboard_type, x.period_type, x.period_start, x.user_id
),
ranked AS (
  SELECT
    pus.leaderboard_type,
    pus.period_type,
    pus.period_start,
    pus.user_id,
    pus.display_name,
    pus.avatar_url,
    GREATEST(pus.current_value - COALESCE(pus.baseline_value, pus.current_value), 0)::bigint AS winner_gain,
    pus.current_value::bigint AS winner_current_score,
    ROW_NUMBER() OVER (
      PARTITION BY pus.leaderboard_type, pus.period_start
      ORDER BY
        GREATEST(pus.current_value - COALESCE(pus.baseline_value, pus.current_value), 0) DESC,
        pus.current_value DESC,
        pus.user_id ASC
    ) AS winner_rank
  FROM period_user_scores pus
),
winners AS (
  SELECT
    r.leaderboard_type,
    r.period_type,
    r.period_start,
    CASE
      WHEN r.period_type = 'monthly'
        THEN r.period_start + INTERVAL '1 month'
      ELSE r.period_start + INTERVAL '7 days'
    END AS period_end,
    r.user_id AS winner_user_id,
    r.display_name AS winner_display_name,
    r.avatar_url AS winner_avatar_url,
    r.winner_gain,
    r.winner_current_score
  FROM ranked r
  WHERE r.winner_rank = 1
)
SELECT
  leaderboard_type,
  period_type,
  period_start,
  period_end,
  winner_user_id,
  winner_display_name,
  winner_avatar_url,
  winner_gain,
  winner_current_score
FROM winners
ORDER BY period_end DESC, leaderboard_type ASC
LIMIT GREATEST(limit_count, 0);
$$;

CREATE OR REPLACE FUNCTION "public"."get_latest_period_winners"(
  "p_period_type" "text" DEFAULT 'weekly'::"text"
) RETURNS TABLE(
  "leaderboard_type" "text",
  "period_type" "text",
  "period_start" timestamp with time zone,
  "period_end" timestamp with time zone,
  "winner_user_id" "uuid",
  "winner_display_name" "text",
  "winner_avatar_url" "text",
  "winner_gain" bigint,
  "winner_current_score" bigint
)
LANGUAGE "sql"
STABLE
AS $$
WITH hall AS (
  SELECT *
  FROM public.get_leaderboard_hall_of_fame(p_period_type, NULL, 500)
),
latest_period AS (
  SELECT MAX(period_start) AS period_start
  FROM hall
)
SELECT
  h.leaderboard_type,
  h.period_type,
  h.period_start,
  h.period_end,
  h.winner_user_id,
  h.winner_display_name,
  h.winner_avatar_url,
  h.winner_gain,
  h.winner_current_score
FROM hall h
JOIN latest_period lp ON lp.period_start = h.period_start
ORDER BY h.leaderboard_type ASC;
$$;

COMMIT;

