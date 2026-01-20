-- Check if Gordon's "Xbox" data includes entries with PSN/Steam metadata
-- This would explain the inflation - PSN trophies being counted as Xbox gamerscore
SELECT 
  ug.game_title_id,
  gt.name,
  gt.xbox_title_id,
  gt.metadata,
  p.code as platform_code,
  ug.xbox_current_gamerscore,
  ug.xbox_achievements_earned
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms p ON p.id = ug.platform_id
WHERE ug.user_id = 'b68ff5b3-c3f1-428f-bcdd-dd3d06f80ba0'
  AND gt.name = 'Resident Evil 4'
ORDER BY ug.xbox_current_gamerscore DESC NULLS LAST;

-- Check how many of Gordon's games have xbox_current_gamerscore > 0 
-- but the game_title has PSN or Steam metadata (cross-platform pollution)
SELECT 
  COUNT(*) as polluted_entries,
  SUM(ug.xbox_current_gamerscore) as total_inflated_gamerscore
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = 'b68ff5b3-c3f1-428f-bcdd-dd3d06f80ba0'
  AND ug.xbox_current_gamerscore > 0
  AND gt.xbox_title_id IS NULL
  AND (
    gt.metadata->>'psn_np_communication_id' IS NOT NULL 
    OR gt.metadata->>'steam_app_id' IS NOT NULL
  );
