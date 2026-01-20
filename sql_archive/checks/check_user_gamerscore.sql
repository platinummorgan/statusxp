-- Check total gamerscore for each Xbox user to find who has 327,990 GS and 487 games

SELECT 
  p.id,
  p.display_name,
  p.xbox_gamertag,
  COUNT(DISTINCT ug.id) as game_count,
  SUM(ug.xbox_current_gamerscore) as total_gs,
  COUNT(DISTINCT CASE WHEN gt.xbox_title_id IS NOT NULL THEN ug.id END) as has_title_id,
  COUNT(DISTINCT CASE WHEN gt.xbox_title_id IS NULL THEN ug.id END) as missing_title_id
FROM profiles p
JOIN user_games ug ON ug.user_id = p.id
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms plat ON plat.id = ug.platform_id
WHERE p.xbox_gamertag IS NOT NULL
  AND plat.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
GROUP BY p.id, p.display_name, p.xbox_gamertag
ORDER BY total_gs DESC;
