-- Check user_games for RE4 (game_title_id 233) without filtering by user
-- Just see all users who have this game
SELECT 
  ug.user_id,
  ug.game_title_id,
  ug.has_platinum,
  ug.earned_trophies,
  ug.total_trophies,
  COUNT(ua.id) as user_achievement_count
FROM user_games ug
LEFT JOIN achievements a ON a.game_title_id = ug.game_title_id
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
WHERE ug.game_title_id = 233
GROUP BY ug.user_id, ug.game_title_id, ug.has_platinum, ug.earned_trophies, ug.total_trophies;
-- Should show: user_achievement_count=0 (deleted), but has_platinum=true

-- RE4 is ready for resync:
-- ✅ game_title_id 233 exists with npCommunicationId NPWR31777_00
-- ✅ All 93 corrupted achievements deleted
-- ✅ user_games still shows has_platinum=true (from PSN)
-- ✅ Ready to recreate 47 achievements + platinum

-- TRIGGER PSN SYNC IN THE APP NOW
-- Sync will:
-- 1. Fetch trophies for NPWR31777_00 from PSN API
-- 2. Create 47 achievements (40 base + 7 DLC) including platinum
-- 3. Recreate user_achievements for your earned trophies
-- 4. Restore platinum in My Games UI
-- 5. Platinum count: 170 → 171
