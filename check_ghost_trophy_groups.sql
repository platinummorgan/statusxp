-- Check if Ghost of Tsushima has hasTrophyGroups flag
SELECT 
  name,
  platform_id,
  metadata->>'has_trophy_groups' as has_trophy_groups,
  metadata->>'hasTrophyGroups' as hasTrophyGroups_alt,
  metadata->>'np_communication_id' as np_comm_id,
  metadata
FROM games
WHERE name ILIKE '%ghost%tsushima%'
  AND platform_id IN (1, 2);

-- Also check the actual achievement trophy_group_id values
SELECT 
  a.metadata->>'trophy_group_id' as trophy_group_id,
  COUNT(*) as count,
  MAX(a.name) as sample_achievement
FROM achievements a
JOIN games g ON a.platform_game_id = g.platform_game_id AND a.platform_id = g.platform_id
WHERE g.name ILIKE '%ghost%tsushima%'
  AND a.platform_id IN (1, 2)
GROUP BY a.metadata->>'trophy_group_id'
ORDER BY trophy_group_id;
