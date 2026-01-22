-- Create functions for achievement-based game grouping
-- Games are grouped if they share >90% of their achievement names (same game, different platforms)

-- Step 1: Function to calculate achievement similarity between two game_titles
CREATE OR REPLACE FUNCTION calculate_achievement_similarity(
  game_id_1 BIGINT,
  game_id_2 BIGINT
)
RETURNS NUMERIC
LANGUAGE plpgsql
AS $$
DECLARE
  total_achievements_1 INT;
  total_achievements_2 INT;
  matching_achievements INT;
  similarity_score NUMERIC;
BEGIN
  -- Count total achievements for each game
  SELECT COUNT(*) INTO total_achievements_1
  FROM achievements
  WHERE game_title_id = game_id_1;
  
  SELECT COUNT(*) INTO total_achievements_2
  FROM achievements
  WHERE game_title_id = game_id_2;
  
  -- If either game has no achievements, return 0
  IF total_achievements_1 = 0 OR total_achievements_2 = 0 THEN
    RETURN 0;
  END IF;
  
  -- Count matching achievement names (case-insensitive, trimmed)
  SELECT COUNT(DISTINCT a1.id) INTO matching_achievements
  FROM achievements a1
  INNER JOIN achievements a2 
    ON LOWER(TRIM(a1.name)) = LOWER(TRIM(a2.name))
  WHERE a1.game_title_id = game_id_1
    AND a2.game_title_id = game_id_2;
  
  -- Calculate similarity as percentage of matching achievements
  -- Use the smaller count as the denominator to handle cases where one platform has DLC
  similarity_score := (matching_achievements::NUMERIC / LEAST(total_achievements_1, total_achievements_2)) * 100;
  
  RETURN similarity_score;
END;
$$;

-- Step 2: Function to get game groups (for Browse All Games)
CREATE OR REPLACE FUNCTION get_grouped_games(
  search_query TEXT DEFAULT NULL,
  platform_filter TEXT DEFAULT NULL,
  result_limit INT DEFAULT 100,
  result_offset INT DEFAULT 0,
  sort_by TEXT DEFAULT 'name_asc'
)
RETURNS TABLE (
  group_id TEXT,        -- Unique identifier for the group
  name TEXT,            -- Game name (from primary entry)
  cover_url TEXT,       -- Cover image
  platforms TEXT[],     -- Array of platform codes
  game_title_ids BIGINT[], -- Array of game_title IDs in this group
  total_achievements INT,  -- Total achievements (from primary entry)
  primary_game_id BIGINT   -- ID of primary game_title for this group
) 
LANGUAGE plpgsql
AS $$
DECLARE
  processed_ids BIGINT[] := ARRAY[]::BIGINT[];
  current_game RECORD;
  similar_game RECORD;
  group_games BIGINT[];
  group_platforms TEXT[];
BEGIN
  -- Create temporary table to store groups
  CREATE TEMP TABLE IF NOT EXISTS temp_game_groups (
    group_id TEXT,
    name TEXT,
    cover_url TEXT,
    platforms TEXT[],
    game_title_ids BIGINT[],
    total_achievements INT,
    primary_game_id BIGINT
  ) ON COMMIT DROP;
  
  -- Iterate through all game_titles
  FOR current_game IN 
    SELECT DISTINCT gt.id, gt.name, gt.cover_url, gt.psn_npwr_id, gt.xbox_title_id, gt.steam_app_id,
           (SELECT COUNT(*) FROM achievements WHERE game_title_id = gt.id) as ach_count
    FROM game_titles gt
    WHERE 
      (search_query IS NULL OR gt.name ILIKE '%' || search_query || '%')
      AND gt.id NOT IN (SELECT UNNEST(processed_ids))
      AND EXISTS (SELECT 1 FROM achievements WHERE game_title_id = gt.id)
    ORDER BY gt.name, gt.id
  LOOP
    -- Skip if already processed
    IF current_game.id = ANY(processed_ids) THEN
      CONTINUE;
    END IF;
    
    -- Start new group with current game
    group_games := ARRAY[current_game.id];
    group_platforms := ARRAY[]::TEXT[];
    
    -- Determine platform for current game
    IF current_game.psn_npwr_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'psn');
    END IF;
    IF current_game.xbox_title_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'xbox');
    END IF;
    IF current_game.steam_app_id IS NOT NULL THEN
      group_platforms := array_append(group_platforms, 'steam');
    END IF;
    
    -- Find similar games (>90% achievement match)
    FOR similar_game IN
      SELECT gt2.id, gt2.psn_npwr_id, gt2.xbox_title_id, gt2.steam_app_id
      FROM game_titles gt2
      WHERE gt2.id != current_game.id
        AND gt2.id NOT IN (SELECT UNNEST(processed_ids))
        AND BTRIM(gt2.name, E' \n\r\t') ILIKE BTRIM(current_game.name, E' \n\r\t') -- Pre-filter by similar name (trim all whitespace)
        AND calculate_achievement_similarity(current_game.id, gt2.id) >= 90
    LOOP
      -- Add to group
      group_games := array_append(group_games, similar_game.id);
      
      -- Add platform
      IF similar_game.psn_npwr_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'psn');
      END IF;
      IF similar_game.xbox_title_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'xbox');
      END IF;
      IF similar_game.steam_app_id IS NOT NULL THEN
        group_platforms := array_append(group_platforms, 'steam');
      END IF;
    END LOOP;
    
    -- Mark all games in group as processed
    processed_ids := processed_ids || group_games;
    
    -- Apply platform filter if specified
    IF platform_filter IS NULL OR platform_filter = ANY(group_platforms) THEN
      INSERT INTO temp_game_groups VALUES (
        'group_' || current_game.id::TEXT,
        current_game.name,
        current_game.cover_url,
        array_remove(ARRAY(SELECT DISTINCT unnest(group_platforms)), NULL),
        group_games,
        current_game.ach_count,
        current_game.id
      );
    END IF;
  END LOOP;
  
  -- Return sorted and paginated results
  RETURN QUERY
  SELECT tgg.*
  FROM temp_game_groups tgg
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN tgg.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN tgg.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Step 3: Function to get user's games with grouping (for My Games)
CREATE OR REPLACE FUNCTION get_user_grouped_games(
  p_user_id UUID
)
RETURNS TABLE (
  group_id TEXT,
  name TEXT,
  cover_url TEXT,
  platforms JSONB[],           -- Array of platform objects with progress
  total_statusxp NUMERIC,
  avg_completion NUMERIC,
  last_played_at TIMESTAMPTZ,
  game_title_ids BIGINT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
  processed_ids BIGINT[] := ARRAY[]::BIGINT[];
  current_game RECORD;
  similar_game RECORD;
  group_games BIGINT[];
  group_platforms JSONB[];
  group_statusxp NUMERIC;
  group_completion NUMERIC;
  latest_played TIMESTAMPTZ;
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS temp_user_game_groups (
    group_id TEXT,
    name TEXT,
    cover_url TEXT,
    platforms JSONB[],
    total_statusxp NUMERIC,
    avg_completion NUMERIC,
    last_played_at TIMESTAMPTZ,
    game_title_ids BIGINT[]
  ) ON COMMIT DROP;
  
  -- Iterate through user's games
  FOR current_game IN
    SELECT DISTINCT 
      gt.id, 
      gt.name, 
      gt.cover_url,
      gt.psn_npwr_id,
      gt.xbox_title_id,
      gt.steam_app_id,
      ug.id as user_game_id,
      CASE 
        WHEN gt.psn_npwr_id IS NOT NULL THEN 'psn'
        WHEN gt.xbox_title_id IS NOT NULL THEN 'xbox'
        WHEN gt.steam_app_id IS NOT NULL THEN 'steam'
        ELSE 'unknown'
      END as platform_code,
      ug.statusxp_effective,
      COALESCE(
        CASE 
          WHEN gt.psn_npwr_id IS NOT NULL AND ug.total_trophies > 0 
            THEN (ug.earned_trophies::NUMERIC / ug.total_trophies * 100)
          WHEN gt.xbox_title_id IS NOT NULL AND ug.xbox_total_achievements > 0
            THEN (ug.xbox_achievements_earned::NUMERIC / ug.xbox_total_achievements * 100)
          WHEN gt.steam_app_id IS NOT NULL AND ug.total_trophies > 0
            THEN (ug.earned_trophies::NUMERIC / ug.total_trophies * 100)
          ELSE 0
        END, 0
      ) as completion,
      ug.last_played_at,
      ug.earned_trophies,
      ug.total_trophies,
      ug.bronze_trophies,
      ug.silver_trophies,
      ug.gold_trophies,
      ug.platinum_trophies,
      ug.xbox_achievements_earned,
      ug.xbox_total_achievements
    FROM game_titles gt
    INNER JOIN user_games ug ON ug.game_title_id = gt.id
    WHERE ug.user_id = p_user_id
      AND gt.id NOT IN (SELECT UNNEST(processed_ids))
    ORDER BY gt.name, gt.id
  LOOP
    IF current_game.id = ANY(processed_ids) THEN
      CONTINUE;
    END IF;
    
    -- Start new group
    group_games := ARRAY[current_game.id];
    group_platforms := ARRAY[jsonb_build_object(
      'code', current_game.platform_code,
      'completion', current_game.completion,
      'statusxp', current_game.statusxp_effective,
      'game_title_id', current_game.id,
      'earned_trophies', current_game.earned_trophies,
      'total_trophies', current_game.total_trophies,
      'bronze_trophies', current_game.bronze_trophies,
      'silver_trophies', current_game.silver_trophies,
      'gold_trophies', current_game.gold_trophies,
      'platinum_trophies', current_game.platinum_trophies,
      'xbox_achievements_earned', current_game.xbox_achievements_earned,
      'xbox_total_achievements', current_game.xbox_total_achievements
    )];
    group_statusxp := COALESCE(current_game.statusxp_effective, 0);
    group_completion := current_game.completion;
    latest_played := current_game.last_played_at;
    
    -- Find similar games in user's library
    FOR similar_game IN
      SELECT DISTINCT
        gt2.id,
        gt2.psn_npwr_id,
        gt2.xbox_title_id,
        gt2.steam_app_id,
        ug2.id as user_game_id,
        CASE 
          WHEN gt2.psn_npwr_id IS NOT NULL THEN 'psn'
          WHEN gt2.xbox_title_id IS NOT NULL THEN 'xbox'
          WHEN gt2.steam_app_id IS NOT NULL THEN 'steam'
          ELSE 'unknown'
        END as platform_code,
        ug2.statusxp_effective,
        COALESCE(
          CASE 
            WHEN gt2.psn_npwr_id IS NOT NULL AND ug2.total_trophies > 0 
              THEN (ug2.earned_trophies::NUMERIC / ug2.total_trophies * 100)
            WHEN gt2.xbox_title_id IS NOT NULL AND ug2.xbox_total_achievements > 0
              THEN (ug2.xbox_achievements_earned::NUMERIC / ug2.xbox_total_achievements * 100)
            WHEN gt2.steam_app_id IS NOT NULL AND ug2.total_trophies > 0
              THEN (ug2.earned_trophies::NUMERIC / ug2.total_trophies * 100)
            ELSE 0
          END, 0
        ) as completion,
        ug2.last_played_at,
        ug2.earned_trophies,
        ug2.total_trophies,
        ug2.bronze_trophies,
        ug2.silver_trophies,
        ug2.gold_trophies,
        ug2.platinum_trophies,
        ug2.xbox_achievements_earned,
        ug2.xbox_total_achievements
      FROM game_titles gt2
      INNER JOIN user_games ug2 ON ug2.game_title_id = gt2.id
      WHERE ug2.user_id = p_user_id
        AND gt2.id != current_game.id
        AND gt2.id NOT IN (SELECT UNNEST(processed_ids))
        AND BTRIM(gt2.name, E' \n\r\t') ILIKE BTRIM(current_game.name, E' \n\r\t') -- Trim all whitespace for comparison
        AND calculate_achievement_similarity(current_game.id, gt2.id) >= 90
    LOOP
      group_games := array_append(group_games, similar_game.id);
      group_platforms := array_append(group_platforms, jsonb_build_object(
        'code', similar_game.platform_code,
        'completion', similar_game.completion,
        'statusxp', similar_game.statusxp_effective,
        'game_title_id', similar_game.id,
        'earned_trophies', similar_game.earned_trophies,
        'total_trophies', similar_game.total_trophies,
        'bronze_trophies', similar_game.bronze_trophies,
        'silver_trophies', similar_game.silver_trophies,
        'gold_trophies', similar_game.gold_trophies,
        'platinum_trophies', similar_game.platinum_trophies,
        'xbox_achievements_earned', similar_game.xbox_achievements_earned,
        'xbox_total_achievements', similar_game.xbox_total_achievements
      ));
      group_statusxp := group_statusxp + COALESCE(similar_game.statusxp_effective, 0);
      group_completion := group_completion + similar_game.completion;
      
      IF similar_game.last_played_at > latest_played OR latest_played IS NULL THEN
        latest_played := similar_game.last_played_at;
      END IF;
    END LOOP;
    
    processed_ids := processed_ids || group_games;
    
    INSERT INTO temp_user_game_groups VALUES (
      'group_' || current_game.id::TEXT,
      current_game.name,
      current_game.cover_url,
      group_platforms,
      group_statusxp,
      group_completion / array_length(group_games, 1),
      latest_played,
      group_games
    );
  END LOOP;
  
  RETURN QUERY
  SELECT tugg.*
  FROM temp_user_game_groups tugg
  ORDER BY tugg.last_played_at DESC NULLS LAST, tugg.name;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION calculate_achievement_similarity TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games TO anon;
GRANT EXECUTE ON FUNCTION get_user_grouped_games TO authenticated;
