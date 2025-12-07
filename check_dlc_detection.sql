-- Check DLC detection across all platforms
SELECT 
  platform,
  is_dlc,
  COUNT(*) as count,
  COUNT(DISTINCT game_title_id) as unique_games
FROM achievements
GROUP BY platform, is_dlc
ORDER BY platform, is_dlc;

-- Show some examples of detected DLC
SELECT 
  gt.name as game_name,
  a.platform,
  a.name as achievement_name,
  a.is_dlc,
  a.dlc_name,
  a.psn_trophy_group_id,
  a.psn_trophy_type
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.is_dlc = true
LIMIT 20;

-- Check PSN trophy groups to see DLC detection
SELECT 
  gt.name as game_name,
  a.psn_trophy_group_id,
  a.is_dlc,
  COUNT(*) as trophy_count
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.platform = 'psn'
GROUP BY gt.name, a.psn_trophy_group_id, a.is_dlc
ORDER BY gt.name, a.psn_trophy_group_id;
