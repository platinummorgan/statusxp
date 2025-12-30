-- Run the EXACT leaderboard query to see what it's calculating
WITH user_totals AS (
  SELECT 
    ug.user_id,
    SUM(CAST(ug.statusxp_effective AS INTEGER)) as total_score,
    COUNT(DISTINCT ug.game_title_id) as game_count
  FROM user_games ug
  GROUP BY ug.user_id
)
SELECT 
  p.display_name,
  p.username,
  ut.total_score,
  ut.game_count
FROM user_totals ut
JOIN profiles p ON p.id = ut.user_id
WHERE p.username = 'Dex-Morgan';

-- Also check if there are duplicate user_games or bad data
SELECT 
  user_id,
  game_title_id,
  platform_id,
  COUNT(*) as duplicate_count
FROM user_games
WHERE user_id = (SELECT id FROM profiles WHERE username = 'Dex-Morgan')
GROUP BY user_id, game_title_id, platform_id
HAVING COUNT(*) > 1;
