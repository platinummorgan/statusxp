-- Check if Steam games exist in user_progress (the SOURCE table for user_games view)
SELECT 
  COUNT(*) as steam_games_count,
  jsonb_agg(jsonb_build_object(
    'platform_game_id', platform_game_id,
    'achievements_earned', achievements_earned,
    'total_achievements', total_achievements,
    'game_name', (SELECT name FROM games WHERE platform_id = 4 AND platform_game_id = up.platform_game_id LIMIT 1)
  )) as steam_games
FROM user_progress up
WHERE user_id = '35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid
  AND platform_id = 4;

-- Check if Steam games exist in games table for this user's games
SELECT 
  g.platform_game_id,
  g.name,
  g.cover_url,
  'EXISTS in games table' as status
FROM games g
WHERE g.platform_id = 4
  AND g.platform_game_id IN (
    SELECT platform_game_id 
    FROM user_progress 
    WHERE user_id = '35029ccf-0d16-4741-a2fe-1e5b9fee4e23'::uuid
      AND platform_id = 4
  )
LIMIT 10;
