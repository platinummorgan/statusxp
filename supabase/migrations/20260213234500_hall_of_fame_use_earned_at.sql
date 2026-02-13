-- Hall of Fame: compute winner gain by earned_at (not snapshot deltas).
-- This matches the seasonal leaderboard "anti-banking" logic.
--
-- Winner current score is taken from the latest snapshot before period_end when available,
-- falling back to current caches.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_leaderboard_hall_of_fame(
  p_period_type text DEFAULT 'weekly',
  p_leaderboard_type text DEFAULT NULL,
  limit_count integer DEFAULT 100
)
RETURNS TABLE(
  leaderboard_type text,
  period_type text,
  period_start timestamptz,
  period_end timestamptz,
  winner_user_id uuid,
  winner_display_name text,
  winner_avatar_url text,
  winner_gain bigint,
  winner_current_score bigint
)
LANGUAGE sql
STABLE
AS $$
WITH settings AS (
  SELECT CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END AS period_type
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
periods_needed AS (
  -- The function returns 4 leaderboards per period (statusxp/psn/xbox/steam).
  -- Compute enough periods to satisfy the final LIMIT after ordering.
  SELECT LEAST(GREATEST(((GREATEST(limit_count, 0) + 3) / 4) + 2, 12), 520) AS n
),
closed_periods AS (
  SELECT
    cb.period_type,
    gs AS period_start,
    CASE
      WHEN cb.period_type = 'monthly' THEN gs + INTERVAL '1 month'
      ELSE gs + INTERVAL '7 days'
    END AS period_end
  FROM current_bounds cb
  CROSS JOIN periods_needed pn
  LEFT JOIN reset_floor rf ON TRUE
  CROSS JOIN LATERAL (
    SELECT generate_series(
      CASE
        WHEN cb.period_type = 'monthly'
          THEN (cb.current_period_start - (pn.n * INTERVAL '1 month'))
        ELSE (cb.current_period_start - (pn.n * INTERVAL '7 days'))
      END,
      CASE
        WHEN cb.period_type = 'monthly'
          THEN (cb.current_period_start - INTERVAL '1 month')
        ELSE (cb.current_period_start - INTERVAL '7 days')
      END,
      CASE
        WHEN cb.period_type = 'monthly' THEN INTERVAL '1 month'
        ELSE INTERVAL '7 days'
      END
    ) AS gs
  ) gen
  WHERE gs < cb.current_period_start
    AND (
      cb.period_type <> 'weekly'
      OR gs >= COALESCE(rf.weekly_floor, '-infinity'::timestamptz)
    )
),
time_bounds AS (
  SELECT
    MIN(cp.period_start) AS min_start,
    MAX(cp.period_end) AS max_end
  FROM closed_periods cp
),
-- =========================
-- Gains per leaderboard
-- =========================
statusxp_gains AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', ua.earned_at)) AT TIME ZONE 'UTC')
      ELSE public.get_leaderboard_period_start('weekly', ua.earned_at)
    END AS period_start,
    ua.user_id,
    SUM((a.base_status_xp) * COALESCE(a.rarity_multiplier, 1.0))::bigint AS gain
  FROM public.user_achievements ua
  JOIN public.achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN current_bounds cb
  CROSS JOIN time_bounds tb
  WHERE ua.earned_at IS NOT NULL
    AND ua.earned_at >= tb.min_start
    AND ua.earned_at < tb.max_end
    AND a.include_in_score = true
  GROUP BY 1, 2
),
psn_gains AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', ua.earned_at)) AT TIME ZONE 'UTC')
      ELSE public.get_leaderboard_period_start('weekly', ua.earned_at)
    END AS period_start,
    ua.user_id,
    COUNT(*) FILTER (WHERE a.is_platinum = true)::bigint AS gain
  FROM public.user_achievements ua
  JOIN public.achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN current_bounds cb
  CROSS JOIN time_bounds tb
  WHERE ua.platform_id IN (1, 2, 5, 9)
    AND ua.earned_at IS NOT NULL
    AND ua.earned_at >= tb.min_start
    AND ua.earned_at < tb.max_end
  GROUP BY 1, 2
),
xbox_gains AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', ua.earned_at)) AT TIME ZONE 'UTC')
      ELSE public.get_leaderboard_period_start('weekly', ua.earned_at)
    END AS period_start,
    ua.user_id,
    SUM(COALESCE(a.score_value, 0))::bigint AS gain
  FROM public.user_achievements ua
  JOIN public.achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN current_bounds cb
  CROSS JOIN time_bounds tb
  WHERE ua.platform_id IN (10, 11, 12)
    AND ua.earned_at IS NOT NULL
    AND ua.earned_at >= tb.min_start
    AND ua.earned_at < tb.max_end
  GROUP BY 1, 2
),
steam_gains AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', ua.earned_at)) AT TIME ZONE 'UTC')
      ELSE public.get_leaderboard_period_start('weekly', ua.earned_at)
    END AS period_start,
    ua.user_id,
    COUNT(*)::bigint AS gain
  FROM public.user_achievements ua
  CROSS JOIN current_bounds cb
  CROSS JOIN time_bounds tb
  WHERE ua.platform_id = 4
    AND ua.earned_at IS NOT NULL
    AND ua.earned_at >= tb.min_start
    AND ua.earned_at < tb.max_end
  GROUP BY 1, 2
),
-- =========================
-- Candidate rows per leaderboard/period/user with gain
-- =========================
statusxp_candidates AS (
  SELECT
    'statusxp'::text AS leaderboard_type,
    cp.period_type,
    cp.period_start,
    cp.period_end,
    g.user_id,
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
    COALESCE(g.gain, 0)::bigint AS gain
  FROM closed_periods cp
  JOIN statusxp_gains g ON g.period_start = cp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
psn_candidates AS (
  SELECT
    'psn'::text AS leaderboard_type,
    cp.period_type,
    cp.period_start,
    cp.period_end,
    g.user_id,
    COALESCE(p.psn_online_id, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.psn_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM closed_periods cp
  JOIN psn_gains g ON g.period_start = cp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
xbox_candidates AS (
  SELECT
    'xbox'::text AS leaderboard_type,
    cp.period_type,
    cp.period_start,
    cp.period_end,
    g.user_id,
    COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.xbox_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM closed_periods cp
  JOIN xbox_gains g ON g.period_start = cp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
steam_candidates AS (
  SELECT
    'steam'::text AS leaderboard_type,
    cp.period_type,
    cp.period_start,
    cp.period_end,
    g.user_id,
    COALESCE(p.steam_display_name, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.steam_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM closed_periods cp
  JOIN steam_gains g ON g.period_start = cp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
all_candidates AS (
  SELECT * FROM statusxp_candidates
  UNION ALL
  SELECT * FROM psn_candidates
  UNION ALL
  SELECT * FROM xbox_candidates
  UNION ALL
  SELECT * FROM steam_candidates
),
filtered AS (
  SELECT ac.*
  FROM all_candidates ac
  WHERE (
    p_leaderboard_type IS NULL
    OR p_leaderboard_type = ''
    OR ac.leaderboard_type = LOWER(p_leaderboard_type)
  )
),
ranked AS (
  SELECT
    f.*,
    ROW_NUMBER() OVER (
      PARTITION BY f.leaderboard_type, f.period_start
      ORDER BY f.gain DESC, f.user_id ASC
    ) AS winner_rank
  FROM filtered f
),
winners AS (
  SELECT
    r.leaderboard_type,
    r.period_type,
    r.period_start,
    r.period_end,
    r.user_id AS winner_user_id,
    r.display_name AS winner_display_name,
    r.avatar_url AS winner_avatar_url,
    r.gain AS winner_gain
  FROM ranked r
  WHERE r.winner_rank = 1
),
enriched AS (
  SELECT
    w.*,
    COALESCE(
      CASE w.leaderboard_type
        WHEN 'statusxp' THEN (
          SELECT lh.total_statusxp::bigint
          FROM public.leaderboard_history lh
          WHERE lh.user_id = w.winner_user_id
            AND lh.snapshot_at < w.period_end
          ORDER BY lh.snapshot_at DESC
          LIMIT 1
        )
        WHEN 'psn' THEN (
          SELECT ph.platinum_count::bigint
          FROM public.psn_leaderboard_history ph
          WHERE ph.user_id = w.winner_user_id
            AND ph.snapshot_at < w.period_end
          ORDER BY ph.snapshot_at DESC
          LIMIT 1
        )
        WHEN 'xbox' THEN (
          SELECT xh.gamerscore::bigint
          FROM public.xbox_leaderboard_history xh
          WHERE xh.user_id = w.winner_user_id
            AND xh.snapshot_at < w.period_end
          ORDER BY xh.snapshot_at DESC
          LIMIT 1
        )
        WHEN 'steam' THEN (
          SELECT sh.achievement_count::bigint
          FROM public.steam_leaderboard_history sh
          WHERE sh.user_id = w.winner_user_id
            AND sh.snapshot_at < w.period_end
          ORDER BY sh.snapshot_at DESC
          LIMIT 1
        )
        ELSE NULL
      END,
      CASE w.leaderboard_type
        WHEN 'statusxp' THEN (
          SELECT lc.total_statusxp::bigint
          FROM public.leaderboard_cache lc
          WHERE lc.user_id = w.winner_user_id
        )
        WHEN 'psn' THEN (
          SELECT plc.platinum_count::bigint
          FROM public.psn_leaderboard_cache plc
          WHERE plc.user_id = w.winner_user_id
        )
        WHEN 'xbox' THEN (
          SELECT xlc.gamerscore::bigint
          FROM public.xbox_leaderboard_cache xlc
          WHERE xlc.user_id = w.winner_user_id
        )
        WHEN 'steam' THEN (
          SELECT slc.achievement_count::bigint
          FROM public.steam_leaderboard_cache slc
          WHERE slc.user_id = w.winner_user_id
        )
        ELSE 0::bigint
      END,
      0::bigint
    ) AS winner_current_score
  FROM winners w
)
SELECT
  e.leaderboard_type,
  e.period_type,
  e.period_start,
  e.period_end,
  e.winner_user_id,
  e.winner_display_name,
  e.winner_avatar_url,
  e.winner_gain,
  e.winner_current_score
FROM enriched e
ORDER BY e.period_end DESC, e.leaderboard_type ASC
LIMIT GREATEST(limit_count, 0);
$$;

CREATE OR REPLACE FUNCTION public.get_latest_period_winners(
  p_period_type text DEFAULT 'weekly'
)
RETURNS TABLE(
  leaderboard_type text,
  period_type text,
  period_start timestamptz,
  period_end timestamptz,
  winner_user_id uuid,
  winner_display_name text,
  winner_avatar_url text,
  winner_gain bigint,
  winner_current_score bigint
)
LANGUAGE sql
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

