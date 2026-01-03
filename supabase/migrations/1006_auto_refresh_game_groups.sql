-- Add automatic refresh trigger for game groups

-- Track when game_titles or achievements change
CREATE TABLE IF NOT EXISTS game_groups_refresh_queue (
  id BIGSERIAL PRIMARY KEY,
  needs_refresh BOOLEAN DEFAULT true,
  last_refresh_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure only one row exists
INSERT INTO game_groups_refresh_queue (needs_refresh) VALUES (false)
ON CONFLICT DO NOTHING;

-- Function to mark groups as needing refresh
CREATE OR REPLACE FUNCTION mark_game_groups_for_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE game_groups_refresh_queue SET needs_refresh = true;
  RETURN NEW;
END;
$$;

-- Trigger when new games are added
CREATE TRIGGER trigger_game_title_inserted
AFTER INSERT ON game_titles
FOR EACH STATEMENT
EXECUTE FUNCTION mark_game_groups_for_refresh();

-- Trigger when achievements are added (new game data)
CREATE TRIGGER trigger_achievements_inserted
AFTER INSERT ON achievements
FOR EACH STATEMENT
EXECUTE FUNCTION mark_game_groups_for_refresh();

-- Modified refresh function that tracks last refresh
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
      WHERE gt2.id > current_game.id
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
    
    -- Create stable group key
    group_key := 'group_' || (SELECT MIN(id) FROM UNNEST(group_games) AS id)::TEXT;
    
    -- Insert group
    INSERT INTO game_groups (group_key, game_title_ids, primary_game_id, platforms)
    VALUES (group_key, group_games, current_game.id, array_remove(ARRAY(SELECT DISTINCT unnest(group_platforms)), NULL));
  END LOOP;
  
  -- Mark refresh as complete
  UPDATE game_groups_refresh_queue 
  SET needs_refresh = false, 
      last_refresh_at = NOW();
  
  RAISE NOTICE 'Refreshed % game groups', (SELECT COUNT(*) FROM game_groups);
END;
$$;

-- Function to check and refresh if needed (call this from sync services)
CREATE OR REPLACE FUNCTION refresh_game_groups_if_needed()
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
  needs_refresh_flag BOOLEAN;
BEGIN
  SELECT needs_refresh INTO needs_refresh_flag
  FROM game_groups_refresh_queue
  LIMIT 1;
  
  IF needs_refresh_flag THEN
    PERFORM refresh_game_groups();
    RETURN true;
  END IF;
  
  RETURN false;
END;
$$;

GRANT EXECUTE ON FUNCTION refresh_game_groups_if_needed TO authenticated;
