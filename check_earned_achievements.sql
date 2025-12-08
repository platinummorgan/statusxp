-- Check if Epic Cycle achievement exists and if it's marked as earned
-- First find the achievement ID for Epic Cycle
SELECT a.id, a.name, a.game_title_id, a.platform
FROM achievements a
WHERE a.game_title_id = 193  -- Assassin's Creed Odyssey
  AND a.name = 'Epic Cycle'
  AND a.platform = 'psn';

-- Check user_achievements for this user
-- Replace YOUR_USER_ID with actual user ID
SELECT ua.achievement_id, ua.earned_at, a.name, a.game_title_id
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE a.game_title_id = 193
  AND a.platform = 'psn'
ORDER BY ua.earned_at DESC;

-- Alternative: Check user_trophies (old PSN format)
SELECT ut.trophy_id, ut.unlocked_at, t.name, t.game_title_id
FROM user_trophies ut
JOIN trophies t ON t.id = ut.trophy_id
WHERE t.game_title_id = 193
ORDER BY ut.unlocked_at DESC;
