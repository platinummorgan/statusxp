-- Check if Steam user_achievements are being created
SELECT COUNT(*) as steam_user_achievements
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'steam';

-- Check if achievements table has Steam data (all achievements, not just earned)
SELECT COUNT(*) as total_steam_achievements_in_db
FROM achievements
WHERE platform = 'steam';

-- Sample of what's in achievements for Steam
SELECT 
  gt.name as game,
  a.name as achievement_name,
  a.rarity_global
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.platform = 'steam'
LIMIT 5;
