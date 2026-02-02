-- Query to see exactly what the user sees in "My Games"
-- User: 35029ccf-0d16-4741-a2fe-1e5b9fee4e23

-- 1. Show raw output from get_user_grouped_games (what the app gets)
SELECT 
  group_id,
  name,
  unnest(platforms) as platform_data,
  last_played_at
FROM get_user_grouped_games('35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid)
ORDER BY last_played_at DESC NULLS LAST;

-- 2. Count games by platform code
SELECT 
  platform_data->>'code' as platform_code,
  COUNT(*) as game_count
FROM (
  SELECT 
    unnest(platforms) as platform_data
  FROM get_user_grouped_games('35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid)
) subquery
GROUP BY platform_data->>'code';

-- 3. Show which user_games rows exist (source data)
SELECT 
  platform_id,
  p.code as platform_code,
  game_title,
  earned_trophies,
  total_trophies,
  completion_percent
FROM user_games ug
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE user_id = '35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid
ORDER BY platform_id, game_title;

-- 4. Specifically check for Steam games in source
SELECT 
  COUNT(*) as steam_games_in_user_games,
  jsonb_agg(game_title) as steam_game_titles
FROM user_games
WHERE user_id = '35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid
  AND platform_id = 4;
