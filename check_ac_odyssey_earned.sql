-- Check if Epic Cycle has user_achievement record for AC Odyssey
SELECT a.id, a.name, a.game_title_id, ua.earned_at, ua.user_id
FROM achievements a
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE a.game_title_id = 171
  AND a.platform = 'psn'
  AND a.name = 'Epic Cycle'
LIMIT 5;

-- Check a few earned achievements for AC Odyssey
SELECT a.id, a.name, ua.earned_at
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE a.game_title_id = 171
  AND a.platform = 'psn'
ORDER BY ua.earned_at DESC
LIMIT 10;
