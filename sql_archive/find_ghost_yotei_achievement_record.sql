-- Find Ghost of Yōtei game and check if platinum achievement exists in achievements table
SELECT 
  gt.id as game_title_id,
  gt.name,
  a.id as achievement_id,
  a.name as achievement_name,
  a.psn_trophy_type
FROM game_titles gt
LEFT JOIN achievements a ON a.game_title_id = gt.id 
  AND a.platform = 'psn' 
  AND a.psn_trophy_type = 'platinum'
WHERE gt.name = 'Ghost of Yōtei';
