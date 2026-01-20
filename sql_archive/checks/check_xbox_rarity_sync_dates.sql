-- Check when Xbox games with NULL rarity were last synced
SELECT 
  gt.name as game_title,
  MAX(ug.updated_at) as last_synced,
  COUNT(DISTINCT a.id) as achievements_without_rarity,
  COUNT(DISTINCT ua.id) as user_earned_achievements,
  -- Check if ANY achievements for this game have rarity
  COUNT(DISTINCT CASE WHEN a2.rarity_global IS NOT NULL THEN a2.id END) as achievements_with_rarity,
  CASE 
    WHEN MAX(ug.updated_at) > NOW() - INTERVAL '30 days' THEN '⚠️ RECENTLY SYNCED - SKIPPING RARITY'
    ELSE '✅ OLD SYNC - WILL FETCH RARITY'
  END as sync_status
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
LEFT JOIN achievements a2 ON a2.game_title_id = a.game_title_id AND a2.platform = 'xbox'
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id
LEFT JOIN user_games ug ON ug.game_title_id = a.game_title_id
WHERE a.platform = 'xbox'
AND a.rarity_global IS NULL
AND a.include_in_score = true
GROUP BY gt.id, gt.name
ORDER BY last_synced DESC NULLS LAST
LIMIT 20;
