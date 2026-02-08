-- Fix leaderboard display names to respect preferred_display_platform setting
-- This ensures StatusXP leaderboard shows the same name as activity feed

CREATE OR REPLACE FUNCTION public.get_leaderboard_with_movement(
  limit_count integer DEFAULT 100,
  offset_count integer DEFAULT 0
)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  total_statusxp bigint,
  total_game_entries integer,
  current_rank bigint,
  previous_rank integer,
  rank_change integer,
  is_new boolean,
  preferred_display_platform text,
  psn_online_id text,
  psn_avatar_url text,
  xbox_gamertag text,
  xbox_avatar_url text,
  steam_display_name text,
  steam_avatar_url text
)
LANGUAGE plpgsql
AS $$
DECLARE
  latest_snapshot_time timestamp with time zone;
BEGIN
  -- Get the most recent snapshot time (excluding current moment)
  SELECT MAX(snapshot_at) INTO latest_snapshot_time
  FROM public.leaderboard_history
  WHERE snapshot_at < now() - INTERVAL '1 hour';  -- At least 1 hour old

  RETURN QUERY
  WITH current_ranks AS (
    SELECT 
      lc.user_id,
      ROW_NUMBER() OVER (ORDER BY lc.total_statusxp DESC) as rank,
      lc.total_statusxp,
      lc.total_game_entries
    FROM public.leaderboard_cache lc
    JOIN public.profiles p ON p.id = lc.user_id
    WHERE p.show_on_leaderboard = true
      AND lc.total_statusxp > 0
  ),
  previous_ranks AS (
    SELECT DISTINCT ON (lh.user_id)
      lh.user_id,
      lh.rank as prev_rank
    FROM public.leaderboard_history lh
    WHERE lh.snapshot_at = latest_snapshot_time
    ORDER BY lh.user_id
  )
  SELECT 
    cr.user_id,
    -- Use platform name based on preferred display platform
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_online_id
        WHEN 'xbox' THEN p.xbox_gamertag
        WHEN 'steam' THEN p.steam_display_name
      END,
      p.psn_online_id,
      p.xbox_gamertag, 
      p.steam_display_name,
      p.username,
      'Player'::text
    ) as display_name,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_avatar_url
        WHEN 'xbox' THEN p.xbox_avatar_url
        WHEN 'steam' THEN p.steam_avatar_url
        ELSE p.avatar_url
      END,
      p.avatar_url
    ) as avatar_url,
    cr.total_statusxp,
    cr.total_game_entries,
    cr.rank::bigint as current_rank,
    pr.prev_rank as previous_rank,
    CASE 
      WHEN pr.prev_rank IS NULL THEN 0
      ELSE (pr.prev_rank - cr.rank::integer)
    END as rank_change,
    (pr.prev_rank IS NULL) as is_new,
    p.preferred_display_platform,
    p.psn_online_id,
    p.psn_avatar_url,
    p.xbox_gamertag,
    p.xbox_avatar_url,
    p.steam_display_name,
    p.steam_avatar_url
  FROM current_ranks cr
  JOIN public.profiles p ON p.id = cr.user_id
  LEFT JOIN previous_ranks pr ON pr.user_id = cr.user_id
  ORDER BY cr.rank
  LIMIT limit_count
  OFFSET offset_count;
END;
$$;
