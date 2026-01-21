-- Fix 11-11: Memories Retold platform assignment
-- Problem: Game is PS4 but was incorrectly created as PS5 with achievements

BEGIN;

-- Step 1: Update achievements from PS5 (platform_id=1) to PS4 (platform_id=2)
UPDATE achievements 
SET platform_id = 2
WHERE platform_id = 1 
  AND platform_game_id = 'NPWR15691_00';

-- Step 2: Update any user_achievements from PS5 to PS4
UPDATE user_achievements
SET platform_id = 2
WHERE platform_id = 1
  AND platform_game_id = 'NPWR15691_00';

-- Step 3: Update any user_progress_v2 entries
UPDATE user_progress_v2
SET platform_id = 2
WHERE platform_id = 1
  AND platform_game_id = 'NPWR15691_00';

-- Step 4: Delete the incorrect PS5 game entry
DELETE FROM games
WHERE platform_id = 1
  AND platform_game_id = 'NPWR15691_00'
  AND name = '11-11: Memories Retold';

-- Step 5: Verify the fix
SELECT 
  g.platform_id,
  p.name as platform_name,
  g.platform_game_id,
  g.name,
  (SELECT COUNT(*) FROM achievements a 
   WHERE a.platform_id = g.platform_id 
     AND a.platform_game_id = g.platform_game_id) as achievement_count
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.name = '11-11: Memories Retold';

COMMIT;

-- Step 6: Refresh the materialized view to reflect changes
SELECT refresh_grouped_games_cache();
