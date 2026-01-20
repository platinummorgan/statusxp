-- Check if top users have cross-platform pollution
-- Shows games with xbox_current_gamerscore but NULL xbox_title_id (PSN/Steam games)
SELECT 
  p.display_name,
  COUNT(*) as games_with_null_xbox_id,
  SUM(ug.xbox_current_gamerscore) as inflated_gamerscore,
  -- Also check their valid Xbox games
  (SELECT COUNT(*) 
   FROM user_games ug2 
   JOIN game_titles gt2 ON gt2.id = ug2.game_title_id
   WHERE ug2.user_id = p.id 
     AND ug2.xbox_current_gamerscore > 0 
     AND gt2.xbox_title_id IS NOT NULL) as valid_xbox_games,
  (SELECT SUM(ug2.xbox_current_gamerscore)
   FROM user_games ug2 
   JOIN game_titles gt2 ON gt2.id = ug2.game_title_id
   WHERE ug2.user_id = p.id 
     AND ug2.xbox_current_gamerscore > 0 
     AND gt2.xbox_title_id IS NOT NULL) as valid_xbox_gamerscore
FROM profiles p
JOIN user_games ug ON ug.user_id = p.id
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.xbox_current_gamerscore > 0
  AND gt.xbox_title_id IS NULL  -- Games without Xbox ID
  AND p.display_name IN ('Otaku EVO IX', 'XxlmThumperxX', 'TeaTonicDark')
GROUP BY p.id, p.display_name
ORDER BY inflated_gamerscore DESC;

-- Also check what platforms each user has synced
SELECT 
  p.display_name,
  CASE WHEN p.xbox_xuid IS NOT NULL THEN 'Xbox' END as has_xbox,
  CASE WHEN p.psn_account_id IS NOT NULL THEN 'PSN' END as has_psn,
  CASE WHEN p.steam_id IS NOT NULL THEN 'Steam' END as has_steam
FROM profiles p
WHERE p.display_name IN ('Otaku EVO IX', 'XxlmThumperxX', 'TeaTonicDark')
ORDER BY p.display_name;
