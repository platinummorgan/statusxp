-- Check how many games are missing cover images

-- 1. Count of games without covers by platform
SELECT 
  p.name as platform,
  p.id as platform_id,
  COUNT(*) as total_games,
  COUNT(g.cover_url) as games_with_covers,
  COUNT(*) - COUNT(g.cover_url) as games_missing_covers,
  ROUND(100.0 * (COUNT(*) - COUNT(g.cover_url)) / COUNT(*), 2) as percent_missing
FROM games g
JOIN platforms p ON p.id = g.platform_id
GROUP BY p.id, p.name
ORDER BY games_missing_covers DESC;

-- 2. Overall totals
SELECT 
  COUNT(*) as total_games,
  COUNT(cover_url) as games_with_covers,
  COUNT(*) - COUNT(cover_url) as games_missing_covers,
  ROUND(100.0 * (COUNT(*) - COUNT(cover_url)) / COUNT(*), 2) as percent_missing
FROM games;

-- 3. Sample of games missing covers (10 examples from each platform)
SELECT 
  p.name as platform,
  g.name,
  g.platform_game_id
FROM games g
JOIN platforms p ON p.id = g.platform_id
WHERE g.cover_url IS NULL
ORDER BY p.name, g.name
LIMIT 50;
