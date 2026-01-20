-- Check where games without xbox_title_id come from
-- and if users actually have them in user_games

SELECT 
  gt.name,
  gt.id,
  gt.xbox_title_id,
  gt.steam_appid,
  gt.psn_np_communication_id,
  COUNT(DISTINCT ug.user_id) as user_count,
  SUM(ug.xbox_current_gamerscore) as total_gs,
  MAX(ug.xbox_current_gamerscore) as max_gs
FROM game_titles gt
LEFT JOIN user_games ug ON ug.game_title_id = gt.id
WHERE gt.xbox_title_id IS NULL
  AND ug.xbox_current_gamerscore IS NOT NULL
  AND ug.xbox_current_gamerscore > 0
GROUP BY gt.id, gt.name, gt.xbox_title_id, gt.steam_appid, gt.psn_np_communication_id
ORDER BY user_count DESC, total_gs DESC
LIMIT 30;
