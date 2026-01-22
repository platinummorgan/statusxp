-- Create table to store pre-computed game groupings
CREATE TABLE IF NOT EXISTS game_groups (
  id BIGSERIAL PRIMARY KEY,
  group_key TEXT NOT NULL,  -- Stable identifier for the group (based on lowest game_title_id)
  game_title_ids BIGINT[] NOT NULL,
  primary_game_id BIGINT NOT NULL REFERENCES game_titles(id),
  platforms TEXT[],
  similarity_score NUMERIC,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_game_groups_game_title_ids ON game_groups USING GIN(game_title_ids);
CREATE INDEX idx_game_groups_primary_game_id ON game_groups(primary_game_id);

-- Function to populate game groups (run once or when games are added)
CREATE OR REPLACE FUNCTION refresh_game_groups()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  processed_ids BIGINT[] := ARRAY[]::BIGINT[];
  current_game RECORD;
  similar_game RECORD;
  group_games BIGINT[];
  group_platforms TEXT[];
  group_key TEXT;
BEGIN
  -- Clear existing groups
  TRUNCATE game_groups;
  
  -- Iterate through all game_titles
  FOR current_game IN 
    SELECT DISTINCT gt.id, gt.name, gt.psn_npwr_id, gt.xbox_title_id, gt.steam_app_id
    FROM game_titles gt
    WHERE EXISTS (SELECT 1 FROM achievements WHERE game_title_id = gt.id)
    ORDER BY gt.id
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
      WHERE gt2.id > current_game.id  -- Only check games with higher IDs to avoid duplicates
        AND BTRIM(gt2.name, E' \n\r\t') ILIKE BTRIM(current_game.name, E' \n\r\t')
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
    
    -- Create stable group key (use lowest game_title_id)
    group_key := 'group_' || (SELECT MIN(id) FROM UNNEST(group_games) AS id)::TEXT;
    
    -- Insert group
    INSERT INTO game_groups (group_key, game_title_ids, primary_game_id, platforms)
    VALUES (group_key, group_games, current_game.id, array_remove(ARRAY(SELECT DISTINCT unnest(group_platforms)), NULL));
  END LOOP;
  
  RAISE NOTICE 'Refreshed % game groups', (SELECT COUNT(*) FROM game_groups);
END;
$$;

-- Fast lookup function using pre-computed groups
CREATE OR REPLACE FUNCTION get_grouped_games_fast(
  search_query TEXT DEFAULT NULL,
  platform_filter TEXT DEFAULT NULL,
  result_limit INT DEFAULT 100,
  result_offset INT DEFAULT 0,
  sort_by TEXT DEFAULT 'name_asc'
)
RETURNS TABLE (
  group_id TEXT,
  name TEXT,
  cover_url TEXT,
  platforms TEXT[],
  game_title_ids BIGINT[],
  total_achievements INT,
  primary_game_id BIGINT
) 
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    gg.group_key as group_id,
    gt.name,
    gt.cover_url,
    gg.platforms,
    gg.game_title_ids,
    (SELECT COUNT(*)::INT FROM achievements WHERE game_title_id = gg.primary_game_id) as total_achievements,
    gg.primary_game_id
  FROM game_groups gg
  JOIN game_titles gt ON gt.id = gg.primary_game_id
  WHERE 
    (search_query IS NULL OR gt.name ILIKE '%' || search_query || '%')
    AND (platform_filter IS NULL OR platform_filter = ANY(gg.platforms))
  ORDER BY
    CASE WHEN sort_by = 'name_asc' THEN gt.name END ASC,
    CASE WHEN sort_by = 'name_desc' THEN gt.name END DESC
  LIMIT result_limit
  OFFSET result_offset;
END;
$$;

-- Grant permissions
GRANT SELECT ON game_groups TO authenticated;
GRANT SELECT ON game_groups TO anon;
GRANT EXECUTE ON FUNCTION refresh_game_groups TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO authenticated;
GRANT EXECUTE ON FUNCTION get_grouped_games_fast TO anon;

-- Initial population (this may take a minute)
SELECT refresh_game_groups();
