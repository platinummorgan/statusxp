-- Check Gordon's data in OLD schema to see why it didn't migrate

-- Get Gordon's user ID
SELECT id, display_name, xbox_gamertag 
FROM profiles 
WHERE display_name = 'Gordon';

-- Check Gordon's user_games entries
SELECT 
  ug.id,
  ug.platform_id,
  p.code as platform_code,
  gt.name as game_name,
  gt.xbox_title_id,
  ug.xbox_current_gamerscore,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
JOIN profiles prof ON prof.id = ug.user_id
WHERE prof.display_name = 'Gordon'
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
LIMIT 10;

-- Count Gordon's Xbox games that SHOULD have migrated
SELECT 
  COUNT(*) as should_migrate,
  COUNT(CASE WHEN gt.xbox_title_id IS NULL THEN 1 END) as missing_title_id,
  COUNT(CASE WHEN ug.xbox_current_gamerscore IS NULL THEN 1 END) as missing_gamerscore,
  SUM(ug.xbox_current_gamerscore) as total_gs
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
JOIN profiles prof ON prof.id = ug.user_id
WHERE prof.display_name = 'Gordon'
  AND p.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX');
