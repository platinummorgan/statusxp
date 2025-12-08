-- Check DLC grouping for AC Odyssey
SELECT 
  COALESCE(dlc_name, 'Base Game') as group_name,
  is_dlc,
  COUNT(*) as achievement_count,
  STRING_AGG(name, ', ' ORDER BY id) as first_few_names
FROM achievements
WHERE game_title_id = 171
  AND platform = 'psn'
GROUP BY dlc_name, is_dlc
ORDER BY is_dlc, dlc_name;

-- Show all achievements with their DLC info
SELECT id, name, is_dlc, dlc_name
FROM achievements
WHERE game_title_id = 171
  AND platform = 'psn'
ORDER BY is_dlc, COALESCE(dlc_name, 'Base Game'), id;
