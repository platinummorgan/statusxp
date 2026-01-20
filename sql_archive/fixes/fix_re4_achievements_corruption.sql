-- FIX RE4 ACHIEVEMENTS CORRUPTION
-- game_title_id 233 has 93 merged achievements from RE4 Original + Remake
-- NO PLATINUM exists in achievements table, preventing it from showing

-- Step 1: Verify current corrupted state
SELECT 
  COUNT(*) as total_achievements,
  COUNT(*) FILTER (WHERE platform_version = 'PS4') as ps4_count,
  COUNT(*) FILTER (WHERE platform_version = 'PS5') as ps5_count,
  COUNT(*) FILTER (WHERE platform_version = 'STEAM') as steam_count,
  COUNT(*) FILTER (WHERE is_platinum) as platinum_count
FROM achievements
WHERE game_title_id = 233;
-- Expected: 93 total, 12 PS4, 35-42 PS5, 46 STEAM, 0 platinums

-- Step 2: Check how many user_achievements will be deleted
SELECT COUNT(*) as user_achievement_count
FROM user_achievements
WHERE achievement_id IN (
  SELECT id FROM achievements WHERE game_title_id = 233
);
-- These will cascade delete when we delete achievements

-- Step 3: DELETE ALL CORRUPTED ACHIEVEMENTS
-- This will cascade delete user_achievements too
DELETE FROM achievements WHERE game_title_id = 233;

-- Step 4: Verify deletion
SELECT COUNT(*) as remaining_achievements
FROM achievements
WHERE game_title_id = 233;
-- Should be 0

-- Step 5: Force RE4 to resync (set last_rarity_sync old)
UPDATE game_titles 
SET last_rarity_sync = '2024-01-01 00:00:00+00'
WHERE id = 233;

-- Step 6: Verify game_title_id 233 is ready for resync
SELECT 
  id,
  name,
  metadata->>'psn_np_communication_id' as np_comm_id,
  last_rarity_sync
FROM game_titles
WHERE id = 233;
-- Should show: id=233, name='Resident Evil 4', np_comm_id='NPWR31777_00', last_rarity_sync old

-- AFTER RUNNING THIS SQL:
-- 1. Trigger PSN sync for Dex-Morgan in the app
-- 2. Sync will recreate all 47 achievements (40 base + 7 DLC) with correct npCommunicationId
-- 3. Platinum trophy will be created in achievements table
-- 4. user_achievements will get the platinum entry
-- 5. My Games will show RE4 with platinum
-- 6. Platinum count should go from 170 → 171
