-- Find Gordon's missing games/gamerscore
-- Check if there are games with xbox_current_gamerscore but not being counted

-- 1. Check total Xbox entries for Gordon (should match his actual stats)
SELECT 
  COUNT(*) as total_xbox_entries,
  COUNT(DISTINCT gt.xbox_title_id) as games_with_xbox_id,
  COUNT(*) FILTER (WHERE gt.xbox_title_id IS NULL) as games_without_xbox_id,
  SUM(ug.xbox_current_gamerscore) as total_all_gamerscore,
  SUM(CASE WHEN gt.xbox_title_id IS NOT NULL THEN ug.xbox_current_gamerscore ELSE 0 END) as gamerscore_with_id,
  SUM(CASE WHEN gt.xbox_title_id IS NULL THEN ug.xbox_current_gamerscore ELSE 0 END) as gamerscore_without_id
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = 'b68ff5b3-c3f1-428f-bcdd-dd3d06f80ba0'
  AND ug.xbox_current_gamerscore > 0;

-- 2. Find games that SHOULD be counted but might not be
-- (games with xbox_title_id and gamerscore, but maybe filtered out somehow)
SELECT 
  gt.name,
  gt.xbox_title_id,
  pl.code as platform,
  ug.xbox_current_gamerscore,
  ug.xbox_achievements_earned,
  CASE 
    WHEN gt.xbox_title_id IS NULL THEN 'Missing xbox_title_id'
    WHEN ug.xbox_current_gamerscore = 0 THEN 'Zero gamerscore'
    ELSE 'Should be counted'
  END as status
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms pl ON pl.id = ug.platform_id
WHERE ug.user_id = 'b68ff5b3-c3f1-428f-bcdd-dd3d06f80ba0'
  AND (ug.xbox_current_gamerscore > 0 OR ug.xbox_achievements_earned > 0)
ORDER BY ug.xbox_current_gamerscore DESC;
