-- Diagnose Xbox game duplication issue

-- 1. Check for game_titles without xbox_title_id (old records from name-only matching)
SELECT 
  COUNT(*) as games_without_xbox_id,
  COUNT(*) FILTER (WHERE metadata ? 'xbox_title_id') as games_with_xbox_id
FROM game_titles
WHERE metadata IS NOT NULL;

-- 2. Find duplicate Xbox games (old name-matched + new unique ID versions)
SELECT 
  gt.name,
  COUNT(*) as duplicate_count,
  STRING_AGG(gt.id::text, ', ') as game_title_ids,
  STRING_AGG(COALESCE(gt.metadata->>'xbox_title_id', 'NO_ID'), ', ') as xbox_title_ids
FROM game_titles gt
WHERE gt.metadata IS NOT NULL
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- 3. Check your Xbox user_games count
SELECT 
  COUNT(*) as total_xbox_games,
  COUNT(*) FILTER (WHERE gt.metadata ? 'xbox_title_id') as games_with_id,
  COUNT(*) FILTER (WHERE NOT (gt.metadata ? 'xbox_title_id')) as games_without_id
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code = 'XBOXONE'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 4. List games without xbox_title_id that you have
SELECT 
  gt.id,
  gt.name,
  ug.xbox_achievements_earned,
  ug.xbox_total_achievements
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE p.code = 'XBOXONE'
  AND ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND NOT (gt.metadata ? 'xbox_title_id')
ORDER BY gt.name
LIMIT 50;

-- CLEANUP (run after reviewing above):
-- Delete old Xbox game_titles without xbox_title_id
-- DELETE FROM game_titles 
-- WHERE id IN (
--   SELECT DISTINCT gt.id
--   FROM game_titles gt
--   JOIN user_games ug ON ug.game_title_id = gt.id
--   JOIN platforms p ON p.id = ug.platform_id
--   WHERE p.code = 'XBOXONE'
--     AND NOT (gt.metadata ? 'xbox_title_id')
-- );
