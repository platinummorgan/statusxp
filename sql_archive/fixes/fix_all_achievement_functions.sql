-- Fix all achievement helper functions to use explicit schema
-- This prevents "relation does not exist" errors when called from web

CREATE OR REPLACE FUNCTION public.check_game_hopper(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  max_games_in_day INTEGER;
BEGIN
  SELECT MAX(game_count) INTO max_games_in_day
  FROM (
    SELECT 
      DATE(ut.earned_at) as earn_date,
      COUNT(DISTINCT ug.game_title_id) as game_count
    FROM public.user_trophies ut
    JOIN public.user_games ug ON ug.user_id = ut.user_id
    JOIN public.trophies t ON t.id = ut.trophy_id AND t.game_title_id = ug.game_title_id
    WHERE ut.user_id = p_user_id
      AND ut.earned_at IS NOT NULL
    GROUP BY DATE(ut.earned_at)
  ) daily_games;
  
  RETURN COALESCE(max_games_in_day, 0) >= 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

CREATE OR REPLACE FUNCTION public.check_power_session(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  max_trophies_in_24h INTEGER;
BEGIN
  SELECT MAX(trophy_count) INTO max_trophies_in_24h
  FROM (
    SELECT 
      ut1.earned_at,
      COUNT(*) as trophy_count
    FROM public.user_trophies ut1
    JOIN public.user_trophies ut2 ON ut2.user_id = ut1.user_id
      AND ut2.earned_at >= ut1.earned_at
      AND ut2.earned_at < ut1.earned_at + INTERVAL '24 hours'
    WHERE ut1.user_id = p_user_id
      AND ut1.earned_at IS NOT NULL
    GROUP BY ut1.earned_at
  ) rolling_counts;
  
  RETURN COALESCE(max_trophies_in_24h, 0) >= 100;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

CREATE OR REPLACE FUNCTION public.check_big_comeback(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM (
      SELECT 
        game_title_id,
        MIN(completion_percent) as min_completion,
        MAX(completion_percent) as max_completion
      FROM public.completion_history
      WHERE user_id = p_user_id
      GROUP BY game_title_id
    ) game_progress
    WHERE min_completion < 10 AND max_completion >= 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

CREATE OR REPLACE FUNCTION public.check_closer(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM (
      SELECT 
        game_title_id,
        MIN(completion_percent) as min_completion,
        MAX(completion_percent) as max_completion
      FROM public.completion_history
      WHERE user_id = p_user_id
      GROUP BY game_title_id
    ) game_progress
    WHERE min_completion < 50 AND max_completion >= 100
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

CREATE OR REPLACE FUNCTION public.check_glow_up(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  earliest_avg NUMERIC;
  latest_avg NUMERIC;
BEGIN
  SELECT AVG(completion_percent) INTO earliest_avg
  FROM (
    SELECT DISTINCT ON (game_title_id) 
      game_title_id,
      completion_percent
    FROM public.completion_history
    WHERE user_id = p_user_id
    ORDER BY game_title_id, recorded_at ASC
  ) earliest;
  
  SELECT AVG(completion_percent) INTO latest_avg
  FROM (
    SELECT DISTINCT ON (game_title_id)
      game_title_id,
      completion_percent
    FROM public.completion_history
    WHERE user_id = p_user_id
    ORDER BY game_title_id, recorded_at DESC
  ) latest;
  
  RETURN COALESCE(latest_avg, 0) - COALESCE(earliest_avg, 0) >= 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';

CREATE OR REPLACE FUNCTION public.check_genre_diversity(p_user_id UUID, p_required_count INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
  unique_genres INTEGER;
BEGIN
  SELECT COUNT(DISTINCT unnest(gt.genres)) INTO unique_genres
  FROM public.user_games ug
  JOIN public.game_titles gt ON gt.id = ug.game_title_id
  WHERE ug.user_id = p_user_id
    AND ug.completion_percent >= 100
    AND gt.genres IS NOT NULL
    AND array_length(gt.genres, 1) > 0;
  
  RETURN COALESCE(unique_genres, 0) >= p_required_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = 'public';
