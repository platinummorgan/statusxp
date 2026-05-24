BEGIN;

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
  ON CONFLICT ON CONSTRAINT user_engagement_challenge_claims_unique_period
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

COMMIT;
