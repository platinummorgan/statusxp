BEGIN;

-- ============================================================
-- Social loop foundation
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_follows (
  follower_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  followed_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_user_id, followed_user_id),
  CONSTRAINT user_follows_no_self_follow CHECK (follower_user_id <> followed_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_follows_followed
  ON public.user_follows (followed_user_id, created_at DESC);

ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_follows_select_own_network ON public.user_follows;
CREATE POLICY user_follows_select_own_network
  ON public.user_follows
  FOR SELECT
  USING (auth.uid() = follower_user_id OR auth.uid() = followed_user_id);

DROP POLICY IF EXISTS user_follows_insert_own ON public.user_follows;
CREATE POLICY user_follows_insert_own
  ON public.user_follows
  FOR INSERT
  WITH CHECK (auth.uid() = follower_user_id AND follower_user_id <> followed_user_id);

DROP POLICY IF EXISTS user_follows_delete_own ON public.user_follows;
CREATE POLICY user_follows_delete_own
  ON public.user_follows
  FOR DELETE
  USING (auth.uid() = follower_user_id);


CREATE TABLE IF NOT EXISTS public.user_rival_watchlist (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rival_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  notify_on_activity boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, rival_user_id),
  CONSTRAINT user_rival_watchlist_no_self_watch CHECK (user_id <> rival_user_id)
);

CREATE INDEX IF NOT EXISTS idx_user_rival_watchlist_rival
  ON public.user_rival_watchlist (rival_user_id, created_at DESC);

ALTER TABLE public.user_rival_watchlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_rival_watchlist_select_own ON public.user_rival_watchlist;
CREATE POLICY user_rival_watchlist_select_own
  ON public.user_rival_watchlist
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_rival_watchlist_insert_own ON public.user_rival_watchlist;
CREATE POLICY user_rival_watchlist_insert_own
  ON public.user_rival_watchlist
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND user_id <> rival_user_id);

DROP POLICY IF EXISTS user_rival_watchlist_update_own ON public.user_rival_watchlist;
CREATE POLICY user_rival_watchlist_update_own
  ON public.user_rival_watchlist
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_rival_watchlist_delete_own ON public.user_rival_watchlist;
CREATE POLICY user_rival_watchlist_delete_own
  ON public.user_rival_watchlist
  FOR DELETE
  USING (auth.uid() = user_id);


-- ============================================================
-- Challenge + notification foundation (push-ready)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  push_enabled boolean NOT NULL DEFAULT true,
  notify_rival_activity boolean NOT NULL DEFAULT true,
  notify_streak_risk boolean NOT NULL DEFAULT true,
  notify_daily_challenges boolean NOT NULL DEFAULT true,
  notify_activity_highlights boolean NOT NULL DEFAULT true,
  daily_digest_hour smallint NOT NULL DEFAULT 19,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_notification_preferences_digest_hour_check
    CHECK (daily_digest_hour >= 0 AND daily_digest_hour <= 23)
);

ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_notification_preferences_select_own ON public.user_notification_preferences;
CREATE POLICY user_notification_preferences_select_own
  ON public.user_notification_preferences
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_notification_preferences_insert_own ON public.user_notification_preferences;
CREATE POLICY user_notification_preferences_insert_own
  ON public.user_notification_preferences
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_notification_preferences_update_own ON public.user_notification_preferences;
CREATE POLICY user_notification_preferences_update_own
  ON public.user_notification_preferences
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_user_notification_preferences_updated_at
  ON public.user_notification_preferences;
CREATE TRIGGER update_user_notification_preferences_updated_at
  BEFORE UPDATE ON public.user_notification_preferences
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


CREATE TABLE IF NOT EXISTS public.user_push_device_tokens (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  platform text NOT NULL DEFAULT 'unknown',
  device_id text,
  push_token text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_push_device_tokens_platform_check
    CHECK (platform IN ('android', 'ios', 'web', 'unknown')),
  CONSTRAINT user_push_device_tokens_unique_token UNIQUE (push_token)
);

CREATE INDEX IF NOT EXISTS idx_user_push_device_tokens_user
  ON public.user_push_device_tokens (user_id, is_active, last_seen_at DESC);

ALTER TABLE public.user_push_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_push_device_tokens_select_own ON public.user_push_device_tokens;
CREATE POLICY user_push_device_tokens_select_own
  ON public.user_push_device_tokens
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_push_device_tokens_insert_own ON public.user_push_device_tokens;
CREATE POLICY user_push_device_tokens_insert_own
  ON public.user_push_device_tokens
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_push_device_tokens_update_own ON public.user_push_device_tokens;
CREATE POLICY user_push_device_tokens_update_own
  ON public.user_push_device_tokens
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS user_push_device_tokens_delete_own ON public.user_push_device_tokens;
CREATE POLICY user_push_device_tokens_delete_own
  ON public.user_push_device_tokens
  FOR DELETE
  USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS update_user_push_device_tokens_updated_at
  ON public.user_push_device_tokens;
CREATE TRIGGER update_user_push_device_tokens_updated_at
  BEFORE UPDATE ON public.user_push_device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


CREATE OR REPLACE FUNCTION public.upsert_push_device_token(
  p_platform text,
  p_push_token text,
  p_device_id text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_platform text := lower(coalesce(p_platform, 'unknown'));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_push_token IS NULL OR btrim(p_push_token) = '' THEN
    RAISE EXCEPTION 'Push token is required';
  END IF;

  IF v_platform NOT IN ('android', 'ios', 'web', 'unknown') THEN
    v_platform := 'unknown';
  END IF;

  INSERT INTO public.user_push_device_tokens (
    user_id,
    platform,
    device_id,
    push_token,
    is_active,
    last_seen_at
  )
  VALUES (
    v_user_id,
    v_platform,
    NULLIF(btrim(p_device_id), ''),
    btrim(p_push_token),
    true,
    now()
  )
  ON CONFLICT (push_token)
  DO UPDATE
  SET
    user_id = EXCLUDED.user_id,
    platform = EXCLUDED.platform,
    device_id = COALESCE(EXCLUDED.device_id, public.user_push_device_tokens.device_id),
    is_active = true,
    last_seen_at = now(),
    updated_at = now();
END;
$$;


-- ============================================================
-- Social graph + highlights RPCs
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_social_graph_snapshot(
  p_user_id uuid DEFAULT auth.uid(),
  p_limit integer DEFAULT 30
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  total_statusxp bigint,
  weekly_gain bigint,
  monthly_gain bigint,
  is_following boolean,
  is_rival_watchlisted boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH actor AS (
  SELECT COALESCE(p_user_id, auth.uid()) AS user_id
),
authorized_actor AS (
  SELECT a.user_id
  FROM actor a
  WHERE a.user_id IS NOT NULL
    AND (a.user_id = auth.uid() OR auth.role() = 'service_role')
),
periods AS (
  SELECT
    public.get_leaderboard_period_start('weekly', now()) AS weekly_start,
    public.get_leaderboard_period_start('monthly', now()) AS monthly_start
),
base_targets AS (
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
    lc.total_statusxp::bigint AS total_statusxp
  FROM authorized_actor aa
  JOIN public.leaderboard_cache lc ON lc.user_id <> aa.user_id
  JOIN public.profiles p ON p.id = lc.user_id
  WHERE p.show_on_leaderboard = true
  ORDER BY lc.total_statusxp DESC, lc.user_id
  LIMIT GREATEST(p_limit, 1)
),
weekly_gains AS (
  SELECT
    ua.user_id,
    COALESCE(SUM(COALESCE(a.base_status_xp, 0)), 0)::bigint AS gain
  FROM base_targets bt
  JOIN public.user_achievements ua ON ua.user_id = bt.user_id
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN periods p
  WHERE ua.earned_at >= p.weekly_start
    AND ua.earned_at < p.weekly_start + interval '7 days'
    AND COALESCE(a.include_in_score, true) = true
  GROUP BY ua.user_id
),
monthly_gains AS (
  SELECT
    ua.user_id,
    COALESCE(SUM(COALESCE(a.base_status_xp, 0)), 0)::bigint AS gain
  FROM base_targets bt
  JOIN public.user_achievements ua ON ua.user_id = bt.user_id
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN periods p
  WHERE ua.earned_at >= p.monthly_start
    AND ua.earned_at < p.monthly_start + interval '1 month'
    AND COALESCE(a.include_in_score, true) = true
  GROUP BY ua.user_id
),
followed AS (
  SELECT uf.followed_user_id AS user_id
  FROM authorized_actor aa
  JOIN public.user_follows uf ON uf.follower_user_id = aa.user_id
),
watchlisted AS (
  SELECT uw.rival_user_id AS user_id
  FROM authorized_actor aa
  JOIN public.user_rival_watchlist uw ON uw.user_id = aa.user_id
)
SELECT
  bt.user_id,
  bt.display_name,
  bt.avatar_url,
  bt.total_statusxp,
  COALESCE(wg.gain, 0) AS weekly_gain,
  COALESCE(mg.gain, 0) AS monthly_gain,
  (f.user_id IS NOT NULL) AS is_following,
  (w.user_id IS NOT NULL) AS is_rival_watchlisted
FROM base_targets bt
LEFT JOIN weekly_gains wg ON wg.user_id = bt.user_id
LEFT JOIN monthly_gains mg ON mg.user_id = bt.user_id
LEFT JOIN followed f ON f.user_id = bt.user_id
LEFT JOIN watchlisted w ON w.user_id = bt.user_id
ORDER BY bt.total_statusxp DESC, bt.user_id;
$$;


CREATE OR REPLACE FUNCTION public.get_social_activity_highlights(
  p_user_id uuid DEFAULT auth.uid(),
  p_limit integer DEFAULT 25
)
RETURNS TABLE (
  id bigint,
  actor_user_id uuid,
  actor_display_name text,
  actor_avatar_url text,
  story_text text,
  event_type text,
  game_title text,
  created_at timestamptz,
  is_following boolean,
  is_rival_watchlisted boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH actor AS (
  SELECT COALESCE(p_user_id, auth.uid()) AS user_id
),
authorized_actor AS (
  SELECT a.user_id
  FROM actor a
  WHERE a.user_id IS NOT NULL
    AND (a.user_id = auth.uid() OR auth.role() = 'service_role')
),
followed AS (
  SELECT uf.followed_user_id AS user_id
  FROM authorized_actor aa
  JOIN public.user_follows uf ON uf.follower_user_id = aa.user_id
),
watchlisted AS (
  SELECT uw.rival_user_id AS user_id
  FROM authorized_actor aa
  JOIN public.user_rival_watchlist uw ON uw.user_id = aa.user_id
)
SELECT
  af.id,
  af.user_id AS actor_user_id,
  af.username AS actor_display_name,
  af.avatar_url AS actor_avatar_url,
  af.story_text,
  af.event_type,
  af.game_title,
  af.created_at,
  (f.user_id IS NOT NULL) AS is_following,
  (w.user_id IS NOT NULL) AS is_rival_watchlisted
FROM authorized_actor aa
JOIN public.activity_feed af
  ON af.user_id <> aa.user_id
LEFT JOIN followed f ON f.user_id = af.user_id
LEFT JOIN watchlisted w ON w.user_id = af.user_id
WHERE af.is_visible = true
  AND af.expires_at >= current_date
  AND (f.user_id IS NOT NULL OR w.user_id IS NOT NULL)
ORDER BY af.created_at DESC
LIMIT GREATEST(p_limit, 1);
$$;


-- ============================================================
-- Challenges + streaks snapshot RPC
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_engagement_snapshot(
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS TABLE (
  current_streak integer,
  longest_streak integer,
  today_unlocks integer,
  weekly_unlocks integer,
  today_statusxp numeric,
  challenges jsonb,
  notification_preferences jsonb
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := COALESCE(p_user_id, auth.uid());
  v_current_streak integer := 0;
  v_longest_streak integer := 0;
  v_today_unlocks integer := 0;
  v_weekly_unlocks integer := 0;
  v_today_statusxp numeric := 0;
  v_challenges jsonb;
  v_preferences jsonb;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_user_id <> auth.uid() AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  WITH days AS (
    SELECT DISTINCT (ua.earned_at AT TIME ZONE 'UTC')::date AS day
    FROM public.user_achievements ua
    WHERE ua.user_id = v_user_id
  ),
  anchor AS (
    SELECT MAX(day) AS latest_day FROM days
  ),
  streak_walk AS (
    WITH RECURSIVE walk(day, streak_len) AS (
      SELECT a.latest_day, 1
      FROM anchor a
      WHERE a.latest_day IS NOT NULL
        AND a.latest_day >= current_date - 1
      UNION ALL
      SELECT w.day - 1, w.streak_len + 1
      FROM walk w
      JOIN days d ON d.day = w.day - 1
    )
    SELECT COALESCE(MAX(streak_len), 0) AS streak_len
    FROM walk
  ),
  longest AS (
    SELECT COALESCE(MAX(streak_len), 0) AS streak_len
    FROM (
      WITH numbered AS (
        SELECT
          day,
          day - (ROW_NUMBER() OVER (ORDER BY day))::int AS grp
        FROM days
      )
      SELECT COUNT(*)::int AS streak_len
      FROM numbered
      GROUP BY grp
    ) s
  )
  SELECT
    COALESCE(sw.streak_len, 0),
    COALESCE(l.streak_len, 0)
  INTO v_current_streak, v_longest_streak
  FROM streak_walk sw
  CROSS JOIN longest l;

  SELECT COUNT(*)::int
  INTO v_today_unlocks
  FROM public.user_achievements ua
  WHERE ua.user_id = v_user_id
    AND (ua.earned_at AT TIME ZONE 'UTC')::date = current_date;

  SELECT COUNT(*)::int
  INTO v_weekly_unlocks
  FROM public.user_achievements ua
  WHERE ua.user_id = v_user_id
    AND (ua.earned_at AT TIME ZONE 'UTC')::date >= current_date - 6;

  SELECT COALESCE(SUM(COALESCE(a.base_status_xp, 0)), 0)
  INTO v_today_statusxp
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = v_user_id
    AND (ua.earned_at AT TIME ZONE 'UTC')::date = current_date
    AND COALESCE(a.include_in_score, true) = true;

  SELECT jsonb_build_object(
      'push_enabled', COALESCE(p.push_enabled, true),
      'notify_rival_activity', COALESCE(p.notify_rival_activity, true),
      'notify_streak_risk', COALESCE(p.notify_streak_risk, true),
      'notify_daily_challenges', COALESCE(p.notify_daily_challenges, true),
      'notify_activity_highlights', COALESCE(p.notify_activity_highlights, true),
      'daily_digest_hour', COALESCE(p.daily_digest_hour, 19)
    )
  INTO v_preferences
  FROM public.user_notification_preferences p
  WHERE p.user_id = v_user_id;

  IF v_preferences IS NULL THEN
    v_preferences := jsonb_build_object(
      'push_enabled', true,
      'notify_rival_activity', true,
      'notify_streak_risk', true,
      'notify_daily_challenges', true,
      'notify_activity_highlights', true,
      'daily_digest_hour', 19
    );
  END IF;

  v_challenges := jsonb_build_array(
    jsonb_build_object(
      'id', 'daily_unlock_sprint',
      'title', 'Daily Unlock Sprint',
      'description', 'Earn 5 achievements today.',
      'target', 5,
      'progress', v_today_unlocks,
      'reward_xp', 25,
      'completed', v_today_unlocks >= 5
    ),
    jsonb_build_object(
      'id', 'weekly_momentum',
      'title', 'Weekly Momentum',
      'description', 'Earn 20 achievements this week.',
      'target', 20,
      'progress', v_weekly_unlocks,
      'reward_xp', 75,
      'completed', v_weekly_unlocks >= 20
    ),
    jsonb_build_object(
      'id', 'xp_burst',
      'title', 'StatusXP Burst',
      'description', 'Gain 100 StatusXP today.',
      'target', 100,
      'progress', floor(v_today_statusxp)::int,
      'reward_xp', 40,
      'completed', floor(v_today_statusxp)::int >= 100
    ),
    jsonb_build_object(
      'id', 'streak_guard',
      'title', 'Streak Guard',
      'description', 'Keep your streak alive (unlock at least 1 achievement every 24h).',
      'target', 1,
      'progress', CASE WHEN v_current_streak > 0 THEN 1 ELSE 0 END,
      'reward_xp', 20,
      'completed', v_current_streak > 0
    )
  );

  RETURN QUERY
  SELECT
    v_current_streak,
    v_longest_streak,
    v_today_unlocks,
    v_weekly_unlocks,
    v_today_statusxp,
    v_challenges,
    v_preferences;
END;
$$;


-- ============================================================
-- "What to play next" recommendation RPC
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_play_next_recommendations(
  p_user_id uuid DEFAULT auth.uid(),
  p_limit integer DEFAULT 18
)
RETURNS TABLE (
  recommendation_type text,
  platform_id integer,
  platform_game_id text,
  game_title text,
  completion_percentage numeric,
  remaining_achievements integer,
  remaining_statusxp numeric,
  estimated_hours numeric,
  xp_per_hour numeric,
  reason text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
WITH actor AS (
  SELECT COALESCE(p_user_id, auth.uid()) AS user_id
),
authorized_actor AS (
  SELECT a.user_id
  FROM actor a
  WHERE a.user_id IS NOT NULL
    AND (a.user_id = auth.uid() OR auth.role() = 'service_role')
),
base AS (
  SELECT
    up.platform_id,
    up.platform_game_id,
    COALESCE(g.name, up.platform_game_id) AS game_title,
    COALESCE(up.completion_percentage, 0)::numeric AS completion_percentage,
    GREATEST(COALESCE(up.total_achievements, 0) - COALESCE(up.achievements_earned, 0), 0)::int AS remaining_achievements,
    COALESCE(rem.remaining_statusxp, 0)::numeric AS remaining_statusxp
  FROM authorized_actor aa
  JOIN public.user_progress up ON up.user_id = aa.user_id
  LEFT JOIN public.games g
    ON g.platform_id = up.platform_id
   AND g.platform_game_id = up.platform_game_id
  LEFT JOIN LATERAL (
    SELECT COALESCE(SUM(COALESCE(a.base_status_xp, 0)), 0)::numeric AS remaining_statusxp
    FROM public.achievements a
    LEFT JOIN public.user_achievements ua
      ON ua.user_id = aa.user_id
     AND ua.platform_id = a.platform_id
     AND ua.platform_game_id = a.platform_game_id
     AND ua.platform_achievement_id = a.platform_achievement_id
    WHERE a.platform_id = up.platform_id
      AND a.platform_game_id = up.platform_game_id
      AND COALESCE(a.include_in_score, true) = true
      AND ua.user_id IS NULL
  ) rem ON true
  WHERE COALESCE(up.total_achievements, 0) > 0
    AND COALESCE(up.achievements_earned, 0) < COALESCE(up.total_achievements, 0)
),
scored AS (
  SELECT
    b.*,
    GREATEST(0.5, b.remaining_achievements::numeric / 6.0) AS estimated_hours,
    CASE
      WHEN b.remaining_achievements <= 0 THEN 0::numeric
      ELSE b.remaining_statusxp / GREATEST(0.5, b.remaining_achievements::numeric / 6.0)
    END AS xp_per_hour
  FROM base b
),
bucket AS (
  SELECT GREATEST(1, p_limit / 3) AS per_bucket
),
closest AS (
  SELECT
    'closest_completion'::text AS recommendation_type,
    s.*,
    ('Highest completion: ' || round(s.completion_percentage, 1)::text || '% with ' || s.remaining_achievements::text || ' left')::text AS reason,
    ROW_NUMBER() OVER (
      ORDER BY s.completion_percentage DESC, s.remaining_achievements ASC, s.remaining_statusxp DESC, s.game_title
    ) AS rn
  FROM scored s
),
easier AS (
  SELECT
    'easiest_wins'::text AS recommendation_type,
    s.*,
    ('Quick wins: only ' || s.remaining_achievements::text || ' achievements remaining')::text AS reason,
    ROW_NUMBER() OVER (
      ORDER BY s.remaining_achievements ASC, s.completion_percentage DESC, s.remaining_statusxp DESC, s.game_title
    ) AS rn
  FROM scored s
),
value_pick AS (
  SELECT
    'best_xp_per_hour'::text AS recommendation_type,
    s.*,
    ('Best XP efficiency: about ' || round(s.xp_per_hour, 1)::text || ' XP/hour potential')::text AS reason,
    ROW_NUMBER() OVER (
      ORDER BY s.xp_per_hour DESC, s.remaining_statusxp DESC, s.remaining_achievements ASC, s.game_title
    ) AS rn
  FROM scored s
)
SELECT
  ranked.recommendation_type,
  ranked.platform_id,
  ranked.platform_game_id,
  ranked.game_title,
  ranked.completion_percentage,
  ranked.remaining_achievements,
  ranked.remaining_statusxp,
  round(ranked.estimated_hours, 2) AS estimated_hours,
  round(ranked.xp_per_hour, 2) AS xp_per_hour,
  ranked.reason
FROM (
  SELECT * FROM closest
  UNION ALL
  SELECT * FROM easier
  UNION ALL
  SELECT * FROM value_pick
) ranked
CROSS JOIN bucket b
WHERE ranked.rn <= b.per_bucket
ORDER BY
  CASE ranked.recommendation_type
    WHEN 'closest_completion' THEN 1
    WHEN 'easiest_wins' THEN 2
    ELSE 3
  END,
  ranked.rn;
$$;


REVOKE ALL ON FUNCTION public.upsert_push_device_token(text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.upsert_push_device_token(text, text, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_social_graph_snapshot(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_social_graph_snapshot(uuid, integer)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_social_activity_highlights(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_social_activity_highlights(uuid, integer)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_user_engagement_snapshot(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_engagement_snapshot(uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_play_next_recommendations(uuid, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_play_next_recommendations(uuid, integer)
  TO authenticated, service_role;

GRANT SELECT, INSERT, DELETE ON public.user_follows TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_rival_watchlist TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.user_notification_preferences TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_push_device_tokens TO authenticated, service_role;
GRANT USAGE, SELECT ON SEQUENCE public.user_push_device_tokens_id_seq TO authenticated, service_role;

COMMIT;
