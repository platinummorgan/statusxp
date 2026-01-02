-- RE4 ACHIEVEMENTS DELETED - READY FOR RESYNC

-- Verify game_title_id 233 is ready (has 0 achievements)
SELECT 
  gt.id,
  gt.name,
  gt.metadata->>'psn_np_communication_id' as np_comm_id,
  COUNT(a.id) as achievement_count
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id
WHERE gt.id = 233
GROUP BY gt.id, gt.name, gt.metadata;
-- Should show: id=233, name='Resident Evil 4', np_comm_id='NPWR31777_00', achievement_count=0

-- Check user_games status (should still show has_platinum=true from PSN)
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
  AND ug.user_id = (SELECT id FROM users WHERE psn_account_id = 'Dex-Morgan')
GROUP BY ug.user_id, ug.game_title_id, ug.has_platinum, ug.earned_trophies, ug.total_trophies;
-- Should show: user_achievement_count=0 (deleted), but has_platinum=true

-- NEXT STEPS:
-- 1. Trigger PSN sync in the app for Dex-Morgan
-- 2. Sync will see game_title_id 233 has 0 achievements
-- 3. Sync will fetch all trophies from PSN API using npCommunicationId
-- 4. Will create 47 achievements (40 base + 7 DLC) including platinum
-- 5. Will recreate user_achievements entries for your earned trophies
-- 6. Platinum will appear in My Games
-- 7. Count should go from 170 → 171
