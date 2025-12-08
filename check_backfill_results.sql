-- Check if backfill worked
SELECT 
  COUNT(*) as total_psn_achievements,
  COUNT(*) FILTER (WHERE is_platinum IS NULL) as missing_is_platinum,
  COUNT(*) FILTER (WHERE include_in_score IS NULL) as missing_include_in_score,
  COUNT(*) FILTER (WHERE rarity_global IS NULL) as missing_rarity,
  COUNT(*) FILTER (WHERE rarity_band IS NULL) as missing_rarity_band
FROM achievements
WHERE platform = 'psn';

-- Check a sample of games to see what's triggering re-fetch
SELECT 
  gt.name,
  COUNT(*) as total_trophies,
  COUNT(*) FILTER (WHERE a.is_platinum IS NOT NULL) as has_platinum_flag,
  COUNT(*) FILTER (WHERE a.include_in_score IS NOT NULL) as has_include_score_flag,
  COUNT(*) FILTER (WHERE a.rarity_global IS NOT NULL) as has_rarity
FROM achievements a
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE a.platform = 'psn'
GROUP BY gt.id, gt.name
ORDER BY total_trophies DESC
LIMIT 10;
