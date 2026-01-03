-- Diagnose Steam game duplication issue

-- 1. Check for game_titles without steam_app_id (old records from name-only matching)
SELECT 
  COUNT(*) as games_without_steam_id,
  COUNT(*) FILTER (WHERE metadata ? 'steam_app_id') as games_with_steam_id
FROM game_titles
WHERE metadata IS NOT NULL;

-- 2. Find duplicate Steam games (old name-matched + new unique ID versions)
SELECT 
  gt.name,
  COUNT(*) as duplicate_count,
  STRING_AGG(gt.id::text, ', ') as game_title_ids,
  STRING_AGG(COALESCE(gt.metadata->>'steam_app_id', 'NO_ID'), ', ') as steam_app_ids
FROM game_titles gt
WHERE gt.metadata IS NOT NULL
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- 3. Check your Steam user_games count
SELECT 
  COUNT(*) as total_steam_games,
  COUNT(*) FILTER (WHERE gt.metadata ? 'steam_app_id') as games_with_id,
  COUNT(*) FILTER (WHERE NOT (gt.metadata ? 'steam_app_id')) as games_without_id
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code = 'STEAM'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 4. List games without steam_app_id that you have
SELECT 
  gt.id,
  gt.name,
  ug.earned_trophies,
  ug.total_trophies
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code = 'STEAM'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND NOT (gt.metadata ? 'steam_app_id')
ORDER BY gt.name
LIMIT 50;
