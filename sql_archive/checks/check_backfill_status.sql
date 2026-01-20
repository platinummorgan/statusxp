-- Check if xbox_title_id was backfilled for X_imThumper_X's games
SELECT 
  COUNT(*) FILTER (WHERE gt.xbox_title_id IS NULL AND ug.xbox_current_gamerscore > 0) as missing_title_id,
  COUNT(*) FILTER (WHERE gt.xbox_title_id IS NOT NULL AND ug.xbox_current_gamerscore > 0) as has_title_id
FROM game_titles gt
JOIN user_games ug ON ug.game_title_id = gt.id
WHERE ug.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND ug.xbox_current_gamerscore IS NOT NULL;
