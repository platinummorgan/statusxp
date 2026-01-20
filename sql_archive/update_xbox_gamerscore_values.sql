-- Update xbox_leaderboard_cache with correct deduplicated gamerscore values
UPDATE xbox_leaderboard_cache
SET gamerscore = correct_scores.total_gamerscore
FROM (
  SELECT 
    user_id,
    SUM(max_gamerscore) as total_gamerscore
  FROM (
    SELECT 
      ug.user_id,
      gt.name as game_name,
      MAX(ug.xbox_current_gamerscore) as max_gamerscore
    FROM user_games ug
    JOIN game_titles gt ON ug.game_title_id = gt.id
    JOIN platforms pl ON ug.platform_id = pl.id
    WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
      AND ug.xbox_current_gamerscore IS NOT NULL
    GROUP BY ug.user_id, gt.name
  ) deduplicated
  GROUP BY user_id
) correct_scores
WHERE xbox_leaderboard_cache.user_id = correct_scores.user_id;

-- Verify the update worked
SELECT 
  display_name,
  gamerscore,
  achievement_count,
  total_games
FROM xbox_leaderboard_cache
ORDER BY gamerscore DESC
LIMIT 10;
