-- GLOBAL CLEANUP: Remove all duplicate platform_game_ids for all affected users
-- Keeps newest platform_id (PS5=1 > PS4=2 > PS3=5 > Vita=9)
-- Database is too large for global queries - clean one user at a time

-- AFFECTED USERS (from earlier audit - 5 total):
-- 1. 68dd426c-3ce9-45e0-a9e6-70a9d3127eb8 (Jasoness) - START HERE
-- Run this script, then get other user IDs from your admin panel

-- Step 1: DELETE duplicates for Jasoness ONLY
-- Simple direct deletes - no subqueries to timeout

-- First, delete PS4 duplicates
DELETE FROM user_achievements
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND platform_id = 2  -- PS4 only
  AND platform_game_id IN (
    'NPWR01864_00', 'NPWR14751_00', 'NPWR11243_00', 'NPWR13826_00', 'NPWR05424_00',
    'NPWR08899_00', 'NPWR06804_00', 'NPWR15120_00', 'NPWR01730_00', 'NPWR06685_00',
    'NPWR09167_00', 'NPWR05403_00', 'NPWR15142_00', 'NPWR06063_00', 'NPWR08983_00',
    'NPWR19151_00', 'NPWR07942_00', 'NPWR11469_00', 'NPWR13348_00', 'NPWR06616_00',
    'NPWR07242_00', 'NPWR07290_00', 'NPWR10664_00', 'NPWR06040_00'
  );

DELETE FROM user_progress
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND platform_id = 2
  AND platform_game_id IN (
    'NPWR01864_00', 'NPWR14751_00', 'NPWR11243_00', 'NPWR13826_00', 'NPWR05424_00',
    'NPWR08899_00', 'NPWR06804_00', 'NPWR15120_00', 'NPWR01730_00', 'NPWR06685_00',
    'NPWR09167_00', 'NPWR05403_00', 'NPWR15142_00', 'NPWR06063_00', 'NPWR08983_00',
    'NPWR19151_00', 'NPWR07942_00', 'NPWR11469_00', 'NPWR13348_00', 'NPWR06616_00',
    'NPWR07242_00', 'NPWR07290_00', 'NPWR10664_00', 'NPWR06040_00'
  );

-- Step 3: Verify Jasoness is clean - check his platinum count
SELECT 
  COUNT(*) as total_platinums
FROM user_achievements ua
JOIN achievements a 
  ON a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
  AND a.is_platinum = true;
