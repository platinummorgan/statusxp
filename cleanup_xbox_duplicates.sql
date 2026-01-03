-- Delete old Xbox game_titles for your account (2 duplicates)

-- Step 1: Verify which records will be deleted
SELECT 
  gt.id,
  gt.name,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements,
  gt.metadata->>'xbox_title_id' as has_xbox_id
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code = 'XBOXONE'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND gt.id IN (2440, 2450);
-- Should show: 2440 (A Plague Tale), 2450 (Stardew Valley) - both NO xbox_title_id

-- Step 2: Verify new versions exist
SELECT 
  gt.id,
  gt.name,
  gt.metadata->>'xbox_title_id' as xbox_title_id
FROM game_titles gt
WHERE gt.name IN ('A Plague Tale: Requiem', 'Stardew Valley')
  AND gt.metadata ? 'xbox_title_id'
ORDER BY gt.name;
-- Should show: 2457 (A Plague Tale with ID 2089483628), 2463 (Stardew with ID 2080211397)

-- Step 3: DELETE old game_titles
-- This will cascade delete user_games and user_achievements
DELETE FROM game_titles WHERE id IN (2440, 2450);

-- Step 4: Verify deletion
SELECT 
  COUNT(*) as remaining_xbox_games
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code = 'XBOXONE'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
-- Should show: 27 games (down from 29)

-- AFTER DELETION: Trigger Xbox sync to recreate user_games for the new game_title records
