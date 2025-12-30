-- Merge DaHead22's duplicate accounts
-- Keep the OLDER email account (c24a7133-e52f-4634-b27d-bbc78483595d) as primary
-- Transfer data from Apple account (3c5206fb-6806-4f95-80d6-29ee7e974be9) to it

BEGIN;

-- Step 1: Transfer user_games from Apple account to email account
UPDATE user_games
SET user_id = 'c24a7133-e52f-4634-b27d-bbc78483595d'
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
-- Only transfer games that don't already exist in the email account
AND NOT EXISTS (
  SELECT 1 FROM user_games ug2
  WHERE ug2.user_id = 'c24a7133-e52f-4634-b27d-bbc78483595d'
  AND ug2.platform_id = user_games.platform_id
  AND ug2.game_title_id = user_games.game_title_id
);

-- Step 2: Delete any remaining duplicate games from Apple account
DELETE FROM user_games
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 3: Transfer achievements
UPDATE user_achievements
SET user_id = 'c24a7133-e52f-4634-b27d-bbc78483595d'
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
AND NOT EXISTS (
  SELECT 1 FROM user_achievements ua2
  WHERE ua2.user_id = 'c24a7133-e52f-4634-b27d-bbc78483595d'
  AND ua2.achievement_id = user_achievements.achievement_id
);

DELETE FROM user_achievements
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 4: Update profile to keep any additional data from Apple account
-- (In case the Apple account has some data the email account doesn't)
UPDATE profiles
SET 
  display_name = COALESCE(profiles.display_name, p2.display_name),
  updated_at = NOW()
FROM profiles p2
WHERE profiles.id = 'c24a7133-e52f-4634-b27d-bbc78483595d'
AND p2.id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 5: Delete the Apple profile
DELETE FROM profiles
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 6: Delete the Apple auth user (THIS REQUIRES ADMIN ACCESS)
-- Note: This needs to be done via Supabase Auth Admin API or Dashboard
-- We can't delete from auth.users directly via SQL for security reasons

-- Step 7: Refresh leaderboard cache
REFRESH MATERIALIZED VIEW CONCURRENTLY leaderboard_cache;

COMMIT;

-- Verify the merge
SELECT 
  p.id,
  COALESCE(p.psn_online_id, p.xbox_gamertag) as platform_name,
  COUNT(DISTINCT ug.game_title_id) as game_count,
  SUM(ug.statusxp_effective) as total_statusxp
FROM profiles p
LEFT JOIN user_games ug ON ug.user_id = p.id
WHERE p.psn_online_id = 'DaHead22' OR p.xbox_gamertag = 'DaHead22'
GROUP BY p.id, p.psn_online_id, p.xbox_gamertag;
