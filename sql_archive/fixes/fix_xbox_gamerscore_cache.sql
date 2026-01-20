-- Fix Xbox gamerscore in leaderboard_cache (deduplicate by game name)
-- This updates the cached gamerscore to the correct deduplicated value

UPDATE leaderboard_cache lc
SET xbox_gamerscore = correct_gs.gamerscore
FROM (
  SELECT 
    ug.user_id,
    SUM(max_scores.max_gs) as gamerscore
  FROM user_games ug
  INNER JOIN (
    SELECT 
      ug2.user_id,
      gt.name as game_name,
      MAX(ug2.xbox_current_gamerscore) as max_gs
    FROM user_games ug2
    INNER JOIN game_titles gt ON ug2.game_title_id = gt.id
    INNER JOIN platforms pl ON ug2.platform_id = pl.id
    WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
    GROUP BY ug2.user_id, gt.name
  ) max_scores ON ug.user_id = max_scores.user_id
  GROUP BY ug.user_id
) correct_gs
WHERE lc.user_id = correct_gs.user_id;

-- Show affected users
SELECT 
  p.username,
  lc.xbox_gamerscore as corrected_gamerscore
FROM leaderboard_cache lc
INNER JOIN profiles p ON lc.user_id = p.id
WHERE lc.xbox_gamerscore > 0
ORDER BY lc.xbox_gamerscore DESC;
