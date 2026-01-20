-- DELETE duplicate xdoscbobbles account (oscarmargan20@gmail.com)
-- Keep the main account (ojjm11@outlook.com) which has both PSN + Xbox

-- This will cascade delete all related data due to foreign key constraints:
-- - user_achievements
-- - user_games  
-- - leaderboard_cache
-- - sync logs
-- etc.

BEGIN;

-- Show what will be deleted
SELECT 'DUPLICATE ACCOUNT TO DELETE:' as info;
SELECT 
  p.id,
  au.email,
  p.xbox_gamertag,
  p.xbox_xuid,
  lc.total_statusxp,
  lc.total_game_entries
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.id = 'c5ff31aa-8572-441a-ab09-22accd4c979b';

-- Delete from auth.users (this will cascade to profiles and everything else)
DELETE FROM auth.users
WHERE id = 'c5ff31aa-8572-441a-ab09-22accd4c979b';

-- Verify deletion
SELECT 'AFTER DELETE - Should be empty:' as info;
SELECT * FROM profiles WHERE id = 'c5ff31aa-8572-441a-ab09-22accd4c979b';

COMMIT;
-- ROLLBACK; -- Uncomment to undo
