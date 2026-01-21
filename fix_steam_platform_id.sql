-- Fix Steam games incorrectly stored as platform_id=5 (PS3)
-- Steam IDs are numeric, PSN IDs start with NPWR/NPUB
-- Only update games with numeric platform_game_id

-- Step 1: Check how many affected Steam games exist (numeric IDs only)
SELECT 
  'games - Steam IDs stored as PS3' as table_name,
  COUNT(*) as affected_count
FROM games
WHERE platform_id = 5
  AND platform_game_id ~ '^\d+$';  -- Only numeric IDs (Steam)

SELECT 
  'games - Real PS3 games' as table_name,
  COUNT(*) as affected_count
FROM games
WHERE platform_id = 5
  AND platform_game_id !~ '^\d+$';  -- PSN format IDs

-- Step 2: Update Steam data from platform_id=5 to platform_id=4
-- Update all tables simultaneously using WITH CTEs
BEGIN;

WITH 
steam_games AS (
  SELECT platform_game_id 
  FROM games 
  WHERE platform_id = 5 
    AND platform_game_id ~ '^\d+$'
),
upd_games AS (
  UPDATE games 
  SET platform_id = 4 
  WHERE platform_id = 5 
    AND platform_game_id IN (SELECT platform_game_id FROM steam_games)
  RETURNING platform_game_id
),
upd_achievements AS (
  UPDATE achievements 
  SET platform_id = 4 
  WHERE platform_id = 5 
    AND platform_game_id IN (SELECT platform_game_id FROM steam_games)
  RETURNING platform_game_id
),
upd_user_achievements AS (
  UPDATE user_achievements 
  SET platform_id = 4 
  WHERE platform_id = 5 
    AND platform_game_id IN (SELECT platform_game_id FROM steam_games)
  RETURNING platform_game_id
),
upd_user_progress AS (
  UPDATE user_progress 
  SET platform_id = 4 
  WHERE platform_id = 5 
    AND platform_game_id IN (SELECT platform_game_id FROM steam_games)
  RETURNING platform_game_id
)
SELECT 
  (SELECT COUNT(*) FROM upd_games) as games_updated,
  (SELECT COUNT(*) FROM upd_achievements) as achievements_updated,
  (SELECT COUNT(*) FROM upd_user_achievements) as user_achievements_updated,
  (SELECT COUNT(*) FROM upd_user_progress) as user_progress_updated;

-- Verify changes
SELECT 'After update - Steam games' as status, COUNT(*) FROM games WHERE platform_id = 4;
SELECT 'After update - PS3 games still on platform 5' as status, COUNT(*) FROM games WHERE platform_id = 5;

COMMIT;
