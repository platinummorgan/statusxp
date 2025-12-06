-- Quick check: Are trophy groups being stored in psn_trophy_groups table?
SELECT 
  COUNT(*) as total_trophy_groups,
  COUNT(DISTINCT game_title_id) as games_with_groups
FROM psn_trophy_groups;

-- Show sample trophy groups
SELECT 
  gt.title as game,
  ptg.trophy_group_id,
  ptg.trophy_group_name,
  ptg.trophy_count_bronze,
  ptg.trophy_count_silver,
  ptg.trophy_count_gold,
  ptg.trophy_count_platinum
FROM psn_trophy_groups ptg
JOIN game_titles gt ON gt.id = ptg.game_title_id
ORDER BY gt.title, ptg.trophy_group_id
LIMIT 20;
