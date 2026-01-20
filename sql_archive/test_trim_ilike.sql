-- Test TRIM and ILIKE with Disney Dreamlight Valley

-- Check the actual names
SELECT 
  id,
  name,
  LENGTH(name) as name_length,
  LENGTH(TRIM(name)) as trimmed_length,
  TRIM(name) as trimmed_name,
  CASE 
    WHEN psn_npwr_id IS NOT NULL THEN 'PSN'
    WHEN xbox_title_id IS NOT NULL THEN 'Xbox'
    WHEN steam_app_id IS NOT NULL THEN 'Steam'
  END as platform
FROM game_titles
WHERE name ILIKE '%Disney Dreamlight Valley%'
ORDER BY id;

-- Test TRIM ILIKE comparison
SELECT 
  gt1.id as game1_id,
  gt1.name as game1_name,
  TRIM(gt1.name) as game1_trimmed,
  gt2.id as game2_id,
  gt2.name as game2_name,
  TRIM(gt2.name) as game2_trimmed,
  (TRIM(gt1.name) ILIKE TRIM(gt2.name)) as names_match,
  calculate_achievement_similarity(gt1.id, gt2.id) as similarity
FROM game_titles gt1
CROSS JOIN game_titles gt2
WHERE gt1.name ILIKE '%Disney Dreamlight Valley%'
  AND gt2.name ILIKE '%Disney Dreamlight Valley%'
  AND gt1.id != gt2.id;
