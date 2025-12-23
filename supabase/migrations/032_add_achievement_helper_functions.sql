-- Helper functions for achievement checking

-- Check if user has earned trophies in 5+ different games on any single day
CREATE OR REPLACE FUNCTION check_game_hopper(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  max_games_in_day INTEGER;
BEGIN
  SELECT MAX(game_count) INTO max_games_in_day
  FROM (
    SELECT 
      DATE(ut.earned_at) as earn_date,
      COUNT(DISTINCT ug.game_title_id) as game_count
    FROM user_trophies ut
    JOIN user_games ug ON ug.user_id = ut.user_id
    JOIN trophies t ON t.id = ut.trophy_id AND t.game_title_id = ug.game_title_id
    WHERE ut.user_id = p_user_id
      AND ut.earned_at IS NOT NULL
    GROUP BY DATE(ut.earned_at)
  ) daily_games;
  
  RETURN COALESCE(max_games_in_day, 0) >= 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user completed 3 games to 100% within a single week
CREATE OR REPLACE FUNCTION check_spike_week(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  max_completions_in_week INTEGER;
BEGIN
  -- This is a simplified check - ideally we'd track when a game hit 100%
  -- For now, check if user has 3+ platinums
  SELECT COUNT(*) INTO max_completions_in_week
  FROM user_games
  WHERE user_id = p_user_id
    AND has_platinum = true;
  
  RETURN COALESCE(max_completions_in_week, 0) >= 3;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user earned 100+ trophies within 24 hours
CREATE OR REPLACE FUNCTION check_power_session(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  max_trophies_in_24h INTEGER;
BEGIN
  SELECT MAX(trophy_count) INTO max_trophies_in_24h
  FROM (
    SELECT 
      ut1.earned_at,
      COUNT(*) as trophy_count
    FROM user_trophies ut1
    JOIN user_trophies ut2 ON ut2.user_id = ut1.user_id
      AND ut2.earned_at >= ut1.earned_at
      AND ut2.earned_at < ut1.earned_at + INTERVAL '24 hours'
    WHERE ut1.user_id = p_user_id
      AND ut1.earned_at IS NOT NULL
    GROUP BY ut1.earned_at
  ) rolling_counts;
  
  RETURN COALESCE(max_trophies_in_24h, 0) >= 100;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user had a "big comeback" - game went from <10% to >=50%
CREATE OR REPLACE FUNCTION check_big_comeback(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM (
      SELECT 
        game_title_id,
        MIN(completion_percent) as min_completion,
        MAX(completion_percent) as max_completion
      FROM completion_history
      WHERE user_id = p_user_id
      GROUP BY game_title_id
    ) game_progress
    WHERE min_completion < 10 AND max_completion >= 50
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user was a "closer" - game went from <50% to 100%
CREATE OR REPLACE FUNCTION check_closer(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM (
      SELECT 
        game_title_id,
        MIN(completion_percent) as min_completion,
        MAX(completion_percent) as max_completion
      FROM completion_history
      WHERE user_id = p_user_id
      GROUP BY game_title_id
    ) game_progress
    WHERE min_completion < 50 AND max_completion >= 100
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user had a "glow up" - average completion increased by 5+ percentage points
CREATE OR REPLACE FUNCTION check_glow_up(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  earliest_avg NUMERIC;
  latest_avg NUMERIC;
BEGIN
  -- Get earliest average completion
  SELECT AVG(completion_percent) INTO earliest_avg
  FROM (
    SELECT DISTINCT ON (game_title_id) 
      game_title_id,
      completion_percent
    FROM completion_history
    WHERE user_id = p_user_id
    ORDER BY game_title_id, recorded_at ASC
  ) earliest;
  
  -- Get latest average completion
  SELECT AVG(completion_percent) INTO latest_avg
  FROM (
    SELECT DISTINCT ON (game_title_id)
      game_title_id,
      completion_percent
    FROM completion_history
    WHERE user_id = p_user_id
    ORDER BY game_title_id, recorded_at DESC
  ) latest;
  
  RETURN COALESCE(latest_avg, 0) - COALESCE(earliest_avg, 0) >= 5;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if user has completed games in N different genres
CREATE OR REPLACE FUNCTION check_genre_diversity(p_user_id UUID, p_required_count INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
  unique_genres INTEGER;
BEGIN
  SELECT COUNT(DISTINCT unnest(gt.genres)) INTO unique_genres
  FROM user_games ug
  JOIN game_titles gt ON gt.id = ug.game_title_id
  WHERE ug.user_id = p_user_id
    AND ug.completion_percent >= 100
    AND gt.genres IS NOT NULL
    AND array_length(gt.genres, 1) > 0;
  
  RETURN COALESCE(unique_genres, 0) >= p_required_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
