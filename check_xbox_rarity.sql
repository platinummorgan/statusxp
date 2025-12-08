-- Check Xbox achievement rarity data from OpenXBL
SELECT 
  gt.name as game,
  a.name as achievement,
  a.rarity_global,
  a.rarity_band,
  a.base_status_xp,
  a.xbox_gamerscore,
  ua.earned_at
FROM achievements a
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE a.platform = 'xbox'
ORDER BY a.rarity_global ASC NULLS LAST
LIMIT 20;

-- Count how many have rarity data
SELECT 
  COUNT(*) as total_xbox_achievements,
  COUNT(CASE WHEN rarity_global IS NOT NULL THEN 1 END) as with_rarity,
  COUNT(CASE WHEN rarity_global IS NULL THEN 1 END) as null_rarity
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'xbox';
