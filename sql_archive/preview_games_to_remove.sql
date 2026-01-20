-- Remove 5 games from Dexmorgan6981's lists to force re-sync
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- First, check current stats
SELECT 
  'Before Removal' as section,
  COUNT(*) FILTER (WHERE platform_id IN (1,2,5,9)) as psn_games,
  COUNT(*) FILTER (WHERE platform_id IN (3,10,11,12)) as xbox_games,
  COUNT(*) FILTER (WHERE platform_id = 4) as steam_games,
  SUM(earned_trophies) as total_achievements_earned
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Get 5 random PSN games to remove (choose low completion ones to minimize data loss)
SELECT 
  'PSN Games to Remove' as section,
  gt.name,
  ug.earned_trophies,
  ug.completion_percent
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id IN (1,2,5,9)
ORDER BY ug.earned_trophies ASC, RANDOM()
LIMIT 5;

-- Get 5 random Xbox games to remove
SELECT 
  'Xbox Games to Remove' as section,
  gt.name,
  ug.xbox_achievements_earned,
  ug.xbox_current_gamerscore
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id IN (3,10,11,12)
ORDER BY ug.xbox_achievements_earned ASC, RANDOM()
LIMIT 5;

-- Get 5 random Steam games to remove
SELECT 
  'Steam Games to Remove' as section,
  gt.name,
  ug.earned_trophies,
  ug.completion_percent
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ug.platform_id = 4
ORDER BY ug.earned_trophies ASC, RANDOM()
LIMIT 5;
