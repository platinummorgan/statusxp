-- Weekly seasonal periods now run Tuesday -> Tuesday (UTC).
-- Adds optional period overrides and resets current weekly window to 2026-02-10..2026-02-17.

BEGIN;

CREATE TABLE IF NOT EXISTS public.seasonal_period_overrides (
  period_type text PRIMARY KEY,
  start_at timestamptz NOT NULL,
  end_at timestamptz,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.get_leaderboard_period_start(
  p_period_type text DEFAULT 'weekly',
  p_reference timestamptz DEFAULT now()
)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_period text := lower(coalesce(p_period_type, 'weekly'));
  v_base timestamptz;
  v_override timestamptz;
BEGIN
  IF v_period = 'monthly' THEN
    v_base := (date_trunc('month', timezone('UTC', p_reference)) AT TIME ZONE 'UTC');
  ELSE
    -- Tuesday-based weekly boundary in UTC.
    v_base := (
      (date_trunc('day', timezone('UTC', p_reference)) AT TIME ZONE 'UTC')
      - (((extract(dow from timezone('UTC', p_reference))::int - 2 + 7) % 7) * interval '1 day')
    );
  END IF;

  SELECT spo.start_at
    INTO v_override
  FROM public.seasonal_period_overrides spo
  WHERE spo.period_type = v_period
    AND spo.start_at <= p_reference
    AND (spo.end_at IS NULL OR p_reference < spo.end_at)
  ORDER BY spo.start_at DESC
  LIMIT 1;

  RETURN coalesce(v_override, v_base);
END;
$$;

GRANT SELECT ON TABLE public.seasonal_period_overrides TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_leaderboard_period_start(text, timestamptz) TO anon, authenticated, service_role;

INSERT INTO public.seasonal_period_overrides (period_type, start_at, end_at, note, updated_at)
VALUES (
  'weekly',
  '2026-02-10 00:00:00+00',
  '2026-02-17 00:00:00+00',
  'One-time fairness reset to Tuesday weekly cadence',
  now()
)
ON CONFLICT (period_type)
DO UPDATE SET
  start_at = EXCLUDED.start_at,
  end_at = EXCLUDED.end_at,
  note = EXCLUDED.note,
  updated_at = now();


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
  SELECT public.get_leaderboard_period_start(p_period_type, now()) AS period_start
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
  SELECT public.get_leaderboard_period_start(p_period_type, now()) AS period_start
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
  SELECT public.get_leaderboard_period_start(p_period_type, now()) AS period_start
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
  SELECT public.get_leaderboard_period_start(p_period_type, now()) AS period_start
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
  WHERE b.period_start < cb.current_period_start
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
