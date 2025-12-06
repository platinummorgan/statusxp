-- Check Xbox achievement rarity data
SELECT 
  gt.name as game,
  a.name as achievement,
  a.rarity_global,
  a.xbox_gamerscore,
  ua.unlocked_at
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'xbox'
ORDER BY ua.unlocked_at DESC
LIMIT 20;

-- Count how many have rarity > 0
SELECT 
  COUNT(*) as total_xbox_achievements,
  COUNT(CASE WHEN rarity_global > 0 THEN 1 END) as with_rarity,
  COUNT(CASE WHEN rarity_global = 0 THEN 1 END) as zero_rarity
FROM achievements a
JOIN user_achievements ua ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND a.platform = 'xbox';
