-- Find achievements with NULL rarity - these are getting 0 points
SELECT 
  a.platform,
  COUNT(*) as achievements_without_rarity,
  COUNT(DISTINCT a.game_title_id) as affected_games
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE a.rarity_global IS NULL
AND a.include_in_score = true
GROUP BY a.platform
ORDER BY achievements_without_rarity DESC;

-- Count how many users are affected
SELECT 
  COUNT(DISTINCT ua.user_id) as affected_users,
  COUNT(*) as total_null_rarity_achievements_earned
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE a.rarity_global IS NULL
AND a.include_in_score = true;
