BEGIN;

CREATE TABLE IF NOT EXISTS public.user_engagement_challenge_claims (
  id bigserial PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  challenge_id text NOT NULL,
  period_type text NOT NULL,
  period_start date NOT NULL,
  reward_xp integer NOT NULL CHECK (reward_xp > 0),
  claimed_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_engagement_challenge_claims_period_type_check
    CHECK (period_type IN ('daily', 'weekly')),
  CONSTRAINT user_engagement_challenge_claims_unique_period
    UNIQUE (user_id, challenge_id, period_type, period_start)
);

CREATE INDEX IF NOT EXISTS idx_user_engagement_challenge_claims_user
  ON public.user_engagement_challenge_claims (user_id, claimed_at DESC);

ALTER TABLE public.user_engagement_challenge_claims ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_engagement_challenge_claims_select_own ON public.user_engagement_challenge_claims;
CREATE POLICY user_engagement_challenge_claims_select_own
  ON public.user_engagement_challenge_claims
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS user_engagement_challenge_claims_insert_own ON public.user_engagement_challenge_claims;
CREATE POLICY user_engagement_challenge_claims_insert_own
  ON public.user_engagement_challenge_claims
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);


CREATE OR REPLACE FUNCTION public.claim_engagement_challenge_reward(
  p_challenge_id text,
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS TABLE (
  challenge_id text,
  reward_xp integer,
  period_type text,
  period_start date,
  claimed_at timestamptz,
  total_reward_xp integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := COALESCE(p_user_id, auth.uid());
  v_challenge_id text := lower(btrim(COALESCE(p_challenge_id, '')));
  v_today date := (now() AT TIME ZONE 'UTC')::date;
  v_week_start date := (
    public.get_leaderboard_period_start('weekly', now()) AT TIME ZONE 'UTC'
  )::date;
  v_today_unlocks integer := 0;
  v_weekly_unlocks integer := 0;
  v_today_statusxp numeric := 0;
  v_latest_unlock_day date := NULL;
  v_target integer := 0;
  v_progress integer := 0;
  v_reward_xp integer := 0;
  v_period_type text := 'daily';
  v_period_start date := v_today;
  v_claimed_at timestamptz := NULL;
  v_total_reward_xp integer := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF v_user_id <> auth.uid() AND auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF v_challenge_id = '' THEN
    RAISE EXCEPTION 'Challenge id is required';
  END IF;

  SELECT COUNT(*)::int
  INTO v_today_unlocks
  FROM public.user_achievements ua
  WHERE ua.user_id = v_user_id
    AND (ua.earned_at AT TIME ZONE 'UTC')::date = v_today;

  SELECT COUNT(*)::int
  INTO v_weekly_unlocks
  FROM public.user_achievements ua
  WHERE ua.user_id = v_user_id
    AND (ua.earned_at AT TIME ZONE 'UTC')::date >= v_week_start
    AND (ua.earned_at AT TIME ZONE 'UTC')::date < v_week_start + 7;

  SELECT COALESCE(SUM(COALESCE(a.base_status_xp, 0)), 0)
  INTO v_today_statusxp
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = v_user_id
    AND (ua.earned_at AT TIME ZONE 'UTC')::date = v_today
    AND COALESCE(a.include_in_score, true) = true;

  SELECT MAX((ua.earned_at AT TIME ZONE 'UTC')::date)
  INTO v_latest_unlock_day
  FROM public.user_achievements ua
  WHERE ua.user_id = v_user_id;

  CASE v_challenge_id
    WHEN 'daily_unlock_sprint' THEN
      v_target := 5;
      v_progress := v_today_unlocks;
      v_reward_xp := 25;
      v_period_type := 'daily';
      v_period_start := v_today;
    WHEN 'weekly_momentum' THEN
      v_target := 20;
      v_progress := v_weekly_unlocks;
      v_reward_xp := 75;
      v_period_type := 'weekly';
      v_period_start := v_week_start;
    WHEN 'xp_burst' THEN
      v_target := 100;
      v_progress := floor(v_today_statusxp)::int;
      v_reward_xp := 40;
      v_period_type := 'daily';
      v_period_start := v_today;
    WHEN 'streak_guard' THEN
      v_target := 1;
      v_progress := CASE
        WHEN v_latest_unlock_day IS NOT NULL AND v_latest_unlock_day >= v_today - 1 THEN 1
        ELSE 0
      END;
      v_reward_xp := 20;
      v_period_type := 'daily';
      v_period_start := v_today;
    ELSE
      RAISE EXCEPTION 'Unknown challenge id: %', v_challenge_id;
  END CASE;

  IF v_progress < v_target THEN
    RAISE EXCEPTION 'Challenge not completed yet';
  END IF;

  INSERT INTO public.user_engagement_challenge_claims (
    user_id,
    challenge_id,
    period_type,
    period_start,
    reward_xp
  )
  VALUES (
    v_user_id,
    v_challenge_id,
    v_period_type,
    v_period_start,
    v_reward_xp
  )
  ON CONFLICT (user_id, challenge_id, period_type, period_start)
  DO NOTHING
  RETURNING user_engagement_challenge_claims.claimed_at INTO v_claimed_at;

  IF v_claimed_at IS NULL THEN
    RAISE EXCEPTION 'Challenge reward already claimed for this period';
  END IF;

  SELECT COALESCE(SUM(c.reward_xp), 0)::int
  INTO v_total_reward_xp
  FROM public.user_engagement_challenge_claims c
  WHERE c.user_id = v_user_id;

  RETURN QUERY
  SELECT
    v_challenge_id,
    v_reward_xp,
    v_period_type,
    v_period_start,
    v_claimed_at,
    v_total_reward_xp;
END;
$$;


DROP FUNCTION IF EXISTS public.get_user_engagement_snapshot(uuid);
CREATE FUNCTION public.get_user_engagement_snapshot(
  p_user_id uuid DEFAULT auth.uid()
)
RETURNS TABLE (
  current_streak integer,
  longest_streak integer,
  today_unlocks integer,
  weekly_unlocks integer,
  today_statusxp numeric,
  total_reward_xp integer,
  weekly_reward_xp integer,
  available_reward_xp integer,
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
  v_today date := (now() AT TIME ZONE 'UTC')::date;
  v_week_start date := (
    public.get_leaderboard_period_start('weekly', now()) AT TIME ZONE 'UTC'
  )::date;
  v_current_streak integer := 0;
  v_longest_streak integer := 0;
  v_today_unlocks integer := 0;
  v_weekly_unlocks integer := 0;
  v_today_statusxp numeric := 0;
  v_total_reward_xp integer := 0;
  v_weekly_reward_xp integer := 0;
  v_available_reward_xp integer := 0;
  v_challenges jsonb;
  v_preferences jsonb;
  v_daily_unlock_claimed boolean := false;
  v_daily_unlock_claimed_at timestamptz := NULL;
  v_weekly_momentum_claimed boolean := false;
  v_weekly_momentum_claimed_at timestamptz := NULL;
  v_xp_burst_claimed boolean := false;
  v_xp_burst_claimed_at timestamptz := NULL;
  v_streak_guard_claimed boolean := false;
  v_streak_guard_claimed_at timestamptz := NULL;
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
        AND a.latest_day >= v_today - 1
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
    AND (ua.earned_at AT TIME ZONE 'UTC')::date = v_today;

  SELECT COUNT(*)::int
  INTO v_weekly_unlocks
  FROM public.user_achievements ua
  WHERE ua.user_id = v_user_id
    AND (ua.earned_at AT TIME ZONE 'UTC')::date >= v_week_start
    AND (ua.earned_at AT TIME ZONE 'UTC')::date < v_week_start + 7;

  SELECT COALESCE(SUM(COALESCE(a.base_status_xp, 0)), 0)
  INTO v_today_statusxp
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.user_id = v_user_id
    AND (ua.earned_at AT TIME ZONE 'UTC')::date = v_today
    AND COALESCE(a.include_in_score, true) = true;

  SELECT c.claimed_at
  INTO v_daily_unlock_claimed_at
  FROM public.user_engagement_challenge_claims c
  WHERE c.user_id = v_user_id
    AND c.challenge_id = 'daily_unlock_sprint'
    AND c.period_type = 'daily'
    AND c.period_start = v_today
  LIMIT 1;
  v_daily_unlock_claimed := v_daily_unlock_claimed_at IS NOT NULL;

  SELECT c.claimed_at
  INTO v_weekly_momentum_claimed_at
  FROM public.user_engagement_challenge_claims c
  WHERE c.user_id = v_user_id
    AND c.challenge_id = 'weekly_momentum'
    AND c.period_type = 'weekly'
    AND c.period_start = v_week_start
  LIMIT 1;
  v_weekly_momentum_claimed := v_weekly_momentum_claimed_at IS NOT NULL;

  SELECT c.claimed_at
  INTO v_xp_burst_claimed_at
  FROM public.user_engagement_challenge_claims c
  WHERE c.user_id = v_user_id
    AND c.challenge_id = 'xp_burst'
    AND c.period_type = 'daily'
    AND c.period_start = v_today
  LIMIT 1;
  v_xp_burst_claimed := v_xp_burst_claimed_at IS NOT NULL;

  SELECT c.claimed_at
  INTO v_streak_guard_claimed_at
  FROM public.user_engagement_challenge_claims c
  WHERE c.user_id = v_user_id
    AND c.challenge_id = 'streak_guard'
    AND c.period_type = 'daily'
    AND c.period_start = v_today
  LIMIT 1;
  v_streak_guard_claimed := v_streak_guard_claimed_at IS NOT NULL;

  SELECT COALESCE(SUM(c.reward_xp), 0)::int
  INTO v_total_reward_xp
  FROM public.user_engagement_challenge_claims c
  WHERE c.user_id = v_user_id;

  SELECT COALESCE(SUM(c.reward_xp), 0)::int
  INTO v_weekly_reward_xp
  FROM public.user_engagement_challenge_claims c
  WHERE c.user_id = v_user_id
    AND (c.claimed_at AT TIME ZONE 'UTC')::date >= v_week_start
    AND (c.claimed_at AT TIME ZONE 'UTC')::date < v_week_start + 7;

  v_available_reward_xp :=
      CASE WHEN v_today_unlocks >= 5 AND NOT v_daily_unlock_claimed THEN 25 ELSE 0 END
    + CASE WHEN v_weekly_unlocks >= 20 AND NOT v_weekly_momentum_claimed THEN 75 ELSE 0 END
    + CASE WHEN floor(v_today_statusxp)::int >= 100 AND NOT v_xp_burst_claimed THEN 40 ELSE 0 END
    + CASE WHEN v_current_streak > 0 AND NOT v_streak_guard_claimed THEN 20 ELSE 0 END;

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
      'completed', v_today_unlocks >= 5,
      'period_type', 'daily',
      'period_start', v_today,
      'claimed', v_daily_unlock_claimed,
      'claimed_at', v_daily_unlock_claimed_at,
      'ready_to_claim', (v_today_unlocks >= 5) AND (NOT v_daily_unlock_claimed)
    ),
    jsonb_build_object(
      'id', 'weekly_momentum',
      'title', 'Weekly Momentum',
      'description', 'Earn 20 achievements this week.',
      'target', 20,
      'progress', v_weekly_unlocks,
      'reward_xp', 75,
      'completed', v_weekly_unlocks >= 20,
      'period_type', 'weekly',
      'period_start', v_week_start,
      'claimed', v_weekly_momentum_claimed,
      'claimed_at', v_weekly_momentum_claimed_at,
      'ready_to_claim', (v_weekly_unlocks >= 20) AND (NOT v_weekly_momentum_claimed)
    ),
    jsonb_build_object(
      'id', 'xp_burst',
      'title', 'StatusXP Burst',
      'description', 'Gain 100 StatusXP today.',
      'target', 100,
      'progress', floor(v_today_statusxp)::int,
      'reward_xp', 40,
      'completed', floor(v_today_statusxp)::int >= 100,
      'period_type', 'daily',
      'period_start', v_today,
      'claimed', v_xp_burst_claimed,
      'claimed_at', v_xp_burst_claimed_at,
      'ready_to_claim', (floor(v_today_statusxp)::int >= 100) AND (NOT v_xp_burst_claimed)
    ),
    jsonb_build_object(
      'id', 'streak_guard',
      'title', 'Streak Guard',
      'description', 'Keep your streak alive (unlock at least 1 achievement every 24h).',
      'target', 1,
      'progress', CASE WHEN v_current_streak > 0 THEN 1 ELSE 0 END,
      'reward_xp', 20,
      'completed', v_current_streak > 0,
      'period_type', 'daily',
      'period_start', v_today,
      'claimed', v_streak_guard_claimed,
      'claimed_at', v_streak_guard_claimed_at,
      'ready_to_claim', (v_current_streak > 0) AND (NOT v_streak_guard_claimed)
    )
  );

  RETURN QUERY
  SELECT
    v_current_streak,
    v_longest_streak,
    v_today_unlocks,
    v_weekly_unlocks,
    v_today_statusxp,
    v_total_reward_xp,
    v_weekly_reward_xp,
    v_available_reward_xp,
    v_challenges,
    v_preferences;
END;
$$;


REVOKE ALL ON FUNCTION public.claim_engagement_challenge_reward(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_engagement_challenge_reward(text, uuid)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_user_engagement_snapshot(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_user_engagement_snapshot(uuid)
  TO authenticated, service_role;

GRANT SELECT, INSERT ON public.user_engagement_challenge_claims
  TO authenticated, service_role;
GRANT USAGE, SELECT ON SEQUENCE public.user_engagement_challenge_claims_id_seq
  TO authenticated, service_role;

COMMIT;
