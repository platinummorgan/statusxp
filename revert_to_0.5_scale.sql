-- Revert base_status_xp back to 0.5 scale (as originally intended)
UPDATE achievements
SET base_status_xp = CASE
    WHEN include_in_score = false THEN 0
    WHEN rarity_global IS NULL THEN 0.5
    WHEN rarity_global > 25 THEN 0.5
    WHEN rarity_global > 10 THEN 0.65
    WHEN rarity_global > 5 THEN 0.9
    WHEN rarity_global > 1 THEN 1.15
    ELSE 1.5
END;

-- Recalculate StatusXP with new values
SELECT calculate_user_game_statusxp();

-- Check new totals
SELECT 
  p.name as platform,
  SUM(ug.statusxp_effective) as platform_statusxp
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = (SELECT id FROM profiles LIMIT 1)
GROUP BY p.name
ORDER BY p.name;

SELECT SUM(statusxp_effective) as total_statusxp
FROM user_games
WHERE user_id = (SELECT id FROM profiles LIMIT 1);
