BEGIN;

CREATE TABLE IF NOT EXISTS "public"."seasonal_leaderboard_baselines" (
  "user_id" uuid NOT NULL,
  "leaderboard_type" text NOT NULL,
  "period_type" text NOT NULL,
  "period_start" timestamp with time zone NOT NULL,
  "baseline_value" bigint NOT NULL,
  "created_at" timestamp with time zone DEFAULT now() NOT NULL,
  "updated_at" timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT "seasonal_leaderboard_baselines_pk" PRIMARY KEY ("user_id", "leaderboard_type", "period_type", "period_start"),
  CONSTRAINT "seasonal_leaderboard_baselines_leaderboard_type_chk" CHECK ("leaderboard_type" IN ('statusxp', 'psn', 'xbox', 'steam')),
  CONSTRAINT "seasonal_leaderboard_baselines_period_type_chk" CHECK ("period_type" IN ('weekly', 'monthly')),
  CONSTRAINT "seasonal_leaderboard_baselines_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS "idx_seasonal_leaderboard_baselines_lookup"
ON "public"."seasonal_leaderboard_baselines" ("leaderboard_type", "period_type", "period_start", "user_id");

CREATE OR REPLACE FUNCTION "public"."ensure_statusxp_seasonal_baselines"(
  "p_period_type" text DEFAULT 'weekly'::text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_period_type text;
  v_period_start timestamp with time zone;
BEGIN
  v_period_type := CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END;

  v_period_start := public.get_leaderboard_period_start(v_period_type, now());

  WITH src AS (
    SELECT
      lc.user_id,
      lc.total_statusxp::bigint AS current_total
    FROM public.leaderboard_cache lc
    JOIN public.profiles p ON p.id = lc.user_id
    WHERE p.show_on_leaderboard = true
      AND lc.total_statusxp > 0
  )
  INSERT INTO public.seasonal_leaderboard_baselines (
    user_id,
    leaderboard_type,
    period_type,
    period_start,
    baseline_value
  )
  SELECT
    s.user_id,
    'statusxp',
    v_period_type,
    v_period_start,
    COALESCE(prev.baseline_total, s.current_total)
  FROM src s
  LEFT JOIN LATERAL (
    SELECT lh.total_statusxp::bigint AS baseline_total
    FROM public.leaderboard_history lh
    WHERE lh.user_id = s.user_id
      AND lh.snapshot_at < v_period_start
    ORDER BY lh.snapshot_at DESC
    LIMIT 1
  ) prev ON true
  ON CONFLICT (user_id, leaderboard_type, period_type, period_start) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."ensure_psn_seasonal_baselines"(
  "p_period_type" text DEFAULT 'weekly'::text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_period_type text;
  v_period_start timestamp with time zone;
BEGIN
  v_period_type := CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END;

  v_period_start := public.get_leaderboard_period_start(v_period_type, now());

  WITH src AS (
    SELECT
      plc.user_id,
      plc.platinum_count::bigint AS current_total
    FROM public.psn_leaderboard_cache plc
    WHERE plc.total_trophies > 0
  )
  INSERT INTO public.seasonal_leaderboard_baselines (
    user_id,
    leaderboard_type,
    period_type,
    period_start,
    baseline_value
  )
  SELECT
    s.user_id,
    'psn',
    v_period_type,
    v_period_start,
    COALESCE(prev.baseline_total, s.current_total)
  FROM src s
  LEFT JOIN LATERAL (
    SELECT ph.platinum_count::bigint AS baseline_total
    FROM public.psn_leaderboard_history ph
    WHERE ph.user_id = s.user_id
      AND ph.snapshot_at < v_period_start
    ORDER BY ph.snapshot_at DESC
    LIMIT 1
  ) prev ON true
  ON CONFLICT (user_id, leaderboard_type, period_type, period_start) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."ensure_xbox_seasonal_baselines"(
  "p_period_type" text DEFAULT 'weekly'::text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_period_type text;
  v_period_start timestamp with time zone;
BEGIN
  v_period_type := CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END;

  v_period_start := public.get_leaderboard_period_start(v_period_type, now());

  WITH src AS (
    SELECT
      xlc.user_id,
      xlc.gamerscore::bigint AS current_total
    FROM public.xbox_leaderboard_cache xlc
    WHERE xlc.gamerscore > 0
  )
  INSERT INTO public.seasonal_leaderboard_baselines (
    user_id,
    leaderboard_type,
    period_type,
    period_start,
    baseline_value
  )
  SELECT
    s.user_id,
    'xbox',
    v_period_type,
    v_period_start,
    COALESCE(prev.baseline_total, s.current_total)
  FROM src s
  LEFT JOIN LATERAL (
    SELECT xh.gamerscore::bigint AS baseline_total
    FROM public.xbox_leaderboard_history xh
    WHERE xh.user_id = s.user_id
      AND xh.snapshot_at < v_period_start
    ORDER BY xh.snapshot_at DESC
    LIMIT 1
  ) prev ON true
  ON CONFLICT (user_id, leaderboard_type, period_type, period_start) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."ensure_steam_seasonal_baselines"(
  "p_period_type" text DEFAULT 'weekly'::text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_period_type text;
  v_period_start timestamp with time zone;
BEGIN
  v_period_type := CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END;

  v_period_start := public.get_leaderboard_period_start(v_period_type, now());

  WITH src AS (
    SELECT
      slc.user_id,
      slc.achievement_count::bigint AS current_total
    FROM public.steam_leaderboard_cache slc
    WHERE slc.achievement_count > 0
  )
  INSERT INTO public.seasonal_leaderboard_baselines (
    user_id,
    leaderboard_type,
    period_type,
    period_start,
    baseline_value
  )
  SELECT
    s.user_id,
    'steam',
    v_period_type,
    v_period_start,
    COALESCE(prev.baseline_total, s.current_total)
  FROM src s
  LEFT JOIN LATERAL (
    SELECT sh.achievement_count::bigint AS baseline_total
    FROM public.steam_leaderboard_history sh
    WHERE sh.user_id = s.user_id
      AND sh.snapshot_at < v_period_start
    ORDER BY sh.snapshot_at DESC
    LIMIT 1
  ) prev ON true
  ON CONFLICT (user_id, leaderboard_type, period_type, period_start) DO NOTHING;
END;
$$;

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
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_period_type text;
BEGIN
  v_period_type := CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END;

  PERFORM public.ensure_statusxp_seasonal_baselines(v_period_type);

  RETURN QUERY
  WITH bounds AS (
    SELECT public.get_leaderboard_period_start(v_period_type, now()) AS period_start
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
  baseline_scores AS (
    SELECT
      cs.user_id,
      COALESCE(sb.baseline_value, cs.current_total) AS baseline_total
    FROM current_scores cs
    CROSS JOIN bounds b
    LEFT JOIN public.seasonal_leaderboard_baselines sb
      ON sb.user_id = cs.user_id
     AND sb.leaderboard_type = 'statusxp'
     AND sb.period_type = v_period_type
     AND sb.period_start = b.period_start
  ),
  ranked AS (
    SELECT
      cs.user_id,
      cs.display_name,
      cs.avatar_url,
      GREATEST(cs.current_total - bs.baseline_total, 0)::bigint AS period_gain,
      cs.current_total,
      bs.baseline_total,
      cs.total_game_entries,
      ROW_NUMBER() OVER (
        ORDER BY
          GREATEST(cs.current_total - bs.baseline_total, 0) DESC,
          cs.current_total DESC,
          cs.user_id ASC
      )::bigint AS current_rank
    FROM current_scores cs
    JOIN baseline_scores bs ON bs.user_id = cs.user_id
  )
  SELECT
    ranked.user_id,
    ranked.display_name,
    ranked.avatar_url,
    ranked.period_gain,
    ranked.current_total,
    ranked.baseline_total,
    ranked.total_game_entries,
    ranked.current_rank
  FROM ranked
  ORDER BY ranked.current_rank
  LIMIT GREATEST(limit_count, 0)
  OFFSET GREATEST(offset_count, 0);
END;
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
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_period_type text;
BEGIN
  v_period_type := CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END;

  PERFORM public.ensure_psn_seasonal_baselines(v_period_type);

  RETURN QUERY
  WITH bounds AS (
    SELECT public.get_leaderboard_period_start(v_period_type, now()) AS period_start
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
  baseline_scores AS (
    SELECT
      cs.user_id,
      COALESCE(sb.baseline_value, cs.platinum_count) AS baseline_platinum
    FROM current_scores cs
    CROSS JOIN bounds b
    LEFT JOIN public.seasonal_leaderboard_baselines sb
      ON sb.user_id = cs.user_id
     AND sb.leaderboard_type = 'psn'
     AND sb.period_type = v_period_type
     AND sb.period_start = b.period_start
  ),
  ranked AS (
    SELECT
      cs.user_id,
      cs.display_name,
      cs.avatar_url,
      GREATEST(cs.platinum_count - bs.baseline_platinum, 0)::bigint AS period_gain,
      cs.platinum_count,
      cs.gold_count,
      cs.silver_count,
      cs.bronze_count,
      cs.total_trophies,
      cs.total_games,
      ROW_NUMBER() OVER (
        ORDER BY
          GREATEST(cs.platinum_count - bs.baseline_platinum, 0) DESC,
          cs.platinum_count DESC,
          cs.gold_count DESC,
          cs.silver_count DESC,
          cs.bronze_count DESC,
          cs.user_id ASC
      )::bigint AS current_rank
    FROM current_scores cs
    JOIN baseline_scores bs ON bs.user_id = cs.user_id
  )
  SELECT
    ranked.user_id,
    ranked.display_name,
    ranked.avatar_url,
    ranked.period_gain,
    ranked.platinum_count,
    ranked.gold_count,
    ranked.silver_count,
    ranked.bronze_count,
    ranked.total_trophies,
    ranked.total_games,
    ranked.current_rank
  FROM ranked
  ORDER BY ranked.current_rank
  LIMIT GREATEST(limit_count, 0)
  OFFSET GREATEST(offset_count, 0);
END;
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
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_period_type text;
BEGIN
  v_period_type := CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END;

  PERFORM public.ensure_xbox_seasonal_baselines(v_period_type);

  RETURN QUERY
  WITH bounds AS (
    SELECT public.get_leaderboard_period_start(v_period_type, now()) AS period_start
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
  baseline_scores AS (
    SELECT
      cs.user_id,
      COALESCE(sb.baseline_value, cs.gamerscore) AS baseline_gamerscore
    FROM current_scores cs
    CROSS JOIN bounds b
    LEFT JOIN public.seasonal_leaderboard_baselines sb
      ON sb.user_id = cs.user_id
     AND sb.leaderboard_type = 'xbox'
     AND sb.period_type = v_period_type
     AND sb.period_start = b.period_start
  ),
  ranked AS (
    SELECT
      cs.user_id,
      cs.display_name,
      cs.avatar_url,
      GREATEST(cs.gamerscore - bs.baseline_gamerscore, 0)::bigint AS period_gain,
      cs.gamerscore,
      cs.potential_gamerscore,
      cs.achievement_count,
      cs.total_games,
      ROW_NUMBER() OVER (
        ORDER BY
          GREATEST(cs.gamerscore - bs.baseline_gamerscore, 0) DESC,
          cs.gamerscore DESC,
          cs.achievement_count DESC,
          cs.user_id ASC
      )::bigint AS current_rank
    FROM current_scores cs
    JOIN baseline_scores bs ON bs.user_id = cs.user_id
  )
  SELECT
    ranked.user_id,
    ranked.display_name,
    ranked.avatar_url,
    ranked.period_gain,
    ranked.gamerscore,
    ranked.potential_gamerscore,
    ranked.achievement_count,
    ranked.total_games,
    ranked.current_rank
  FROM ranked
  ORDER BY ranked.current_rank
  LIMIT GREATEST(limit_count, 0)
  OFFSET GREATEST(offset_count, 0);
END;
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
LANGUAGE plpgsql
VOLATILE
AS $$
DECLARE
  v_period_type text;
BEGIN
  v_period_type := CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END;

  PERFORM public.ensure_steam_seasonal_baselines(v_period_type);

  RETURN QUERY
  WITH bounds AS (
    SELECT public.get_leaderboard_period_start(v_period_type, now()) AS period_start
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
  baseline_scores AS (
    SELECT
      cs.user_id,
      COALESCE(sb.baseline_value, cs.achievement_count) AS baseline_achievements
    FROM current_scores cs
    CROSS JOIN bounds b
    LEFT JOIN public.seasonal_leaderboard_baselines sb
      ON sb.user_id = cs.user_id
     AND sb.leaderboard_type = 'steam'
     AND sb.period_type = v_period_type
     AND sb.period_start = b.period_start
  ),
  ranked AS (
    SELECT
      cs.user_id,
      cs.display_name,
      cs.avatar_url,
      GREATEST(cs.achievement_count - bs.baseline_achievements, 0)::bigint AS period_gain,
      cs.achievement_count,
      cs.potential_achievements,
      cs.total_games,
      ROW_NUMBER() OVER (
        ORDER BY
          GREATEST(cs.achievement_count - bs.baseline_achievements, 0) DESC,
          cs.achievement_count DESC,
          cs.total_games DESC,
          cs.user_id ASC
      )::bigint AS current_rank
    FROM current_scores cs
    JOIN baseline_scores bs ON bs.user_id = cs.user_id
  )
  SELECT
    ranked.user_id,
    ranked.display_name,
    ranked.avatar_url,
    ranked.period_gain,
    ranked.achievement_count,
    ranked.potential_achievements,
    ranked.total_games,
    ranked.current_rank
  FROM ranked
  ORDER BY ranked.current_rank
  LIMIT GREATEST(limit_count, 0)
  OFFSET GREATEST(offset_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION "public"."ensure_statusxp_seasonal_baselines"(text) TO "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "public"."ensure_psn_seasonal_baselines"(text) TO "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "public"."ensure_xbox_seasonal_baselines"(text) TO "anon", "authenticated", "service_role";
GRANT EXECUTE ON FUNCTION "public"."ensure_steam_seasonal_baselines"(text) TO "anon", "authenticated", "service_role";

COMMIT;
