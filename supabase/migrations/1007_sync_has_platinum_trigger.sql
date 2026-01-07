-- Sync has_platinum with user_achievements as single source of truth
-- This trigger ensures user_games.has_platinum always matches reality

-- Function to sync has_platinum for a specific user/game combination
CREATE OR REPLACE FUNCTION sync_has_platinum_for_game(p_user_id UUID, p_game_title_id BIGINT, p_platform_id INT)
RETURNS void AS $$
DECLARE
  v_has_platinum BOOLEAN;
BEGIN
  -- Check if user has earned the platinum trophy for this game
  SELECT EXISTS (
    SELECT 1 
    FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = p_user_id
      AND a.game_title_id = p_game_title_id
      AND a.psn_trophy_type = 'platinum'
      AND a.platform = 'psn'
  ) INTO v_has_platinum;
  
  -- Update user_games
  UPDATE user_games
  SET has_platinum = v_has_platinum,
      platinum_trophies = CASE WHEN v_has_platinum THEN 1 ELSE 0 END
  WHERE user_id = p_user_id
    AND game_title_id = p_game_title_id
    AND platform_id = p_platform_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger function for when achievements are inserted/deleted
CREATE OR REPLACE FUNCTION trigger_sync_has_platinum()
RETURNS TRIGGER AS $$
DECLARE
  v_game_title_id BIGINT;
  v_platform_id INT;
BEGIN
  -- Get game_title_id from the achievement
  IF TG_OP = 'DELETE' THEN
    SELECT a.game_title_id INTO v_game_title_id
    FROM achievements a
    WHERE a.id = OLD.achievement_id;
    
    -- Only process platinum trophies
    IF EXISTS (
      SELECT 1 FROM achievements 
      WHERE id = OLD.achievement_id 
        AND psn_trophy_type = 'platinum'
        AND platform = 'psn'
    ) THEN
      -- Sync for PSN (platform_id = 1)
      PERFORM sync_has_platinum_for_game(OLD.user_id, v_game_title_id, 1);
    END IF;
  ELSE
    SELECT a.game_title_id INTO v_game_title_id
    FROM achievements a
    WHERE a.id = NEW.achievement_id;
    
    -- Only process platinum trophies
    IF EXISTS (
      SELECT 1 FROM achievements 
      WHERE id = NEW.achievement_id 
        AND psn_trophy_type = 'platinum'
        AND platform = 'psn'
    ) THEN
      -- Sync for PSN (platform_id = 1)
      PERFORM sync_has_platinum_for_game(NEW.user_id, v_game_title_id, 1);
    END IF;
  END IF;
  
  RETURN NULL; -- AFTER trigger, return value doesn't matter
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_has_platinum_on_insert ON user_achievements;
DROP TRIGGER IF EXISTS sync_has_platinum_on_delete ON user_achievements;

-- Create triggers
CREATE TRIGGER sync_has_platinum_on_insert
  AFTER INSERT ON user_achievements
  FOR EACH ROW
  EXECUTE FUNCTION trigger_sync_has_platinum();

CREATE TRIGGER sync_has_platinum_on_delete
  AFTER DELETE ON user_achievements
  FOR EACH ROW
  EXECUTE FUNCTION trigger_sync_has_platinum();

-- One-time fix: Sync all existing has_platinum values
DO $$
DECLARE
  v_record RECORD;
  v_count INT := 0;
BEGIN
  RAISE NOTICE 'Starting one-time sync of all has_platinum values...';
  
  FOR v_record IN 
    SELECT DISTINCT ug.user_id, ug.game_title_id, ug.platform_id
    FROM user_games ug
    WHERE ug.platform_id = 1  -- PSN only
  LOOP
    PERFORM sync_has_platinum_for_game(
      v_record.user_id, 
      v_record.game_title_id, 
      v_record.platform_id
    );
    v_count := v_count + 1;
  END LOOP;
  
  RAISE NOTICE 'Synced % game records', v_count;
END $$;

-- Verify the fix worked for DaHead22
SELECT 
  p.psn_online_id,
  COUNT(*) FILTER (WHERE ug.has_platinum = true) as games_with_platinum_flag,
  COUNT(*) FILTER (WHERE EXISTS (
    SELECT 1 FROM user_achievements ua
    JOIN achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = ug.user_id
      AND a.game_title_id = ug.game_title_id
      AND a.psn_trophy_type = 'platinum'
  )) as games_with_platinum_achievement
FROM profiles p
JOIN user_games ug ON ug.user_id = p.id
WHERE p.psn_online_id = 'DaHead22'
  AND ug.platform_id = 1
GROUP BY p.psn_online_id;
