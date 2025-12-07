-- ============================================================================
-- FIX: Delete duplicate Xbox game_titles and re-link to existing PSN games
-- ============================================================================

-- Step 1: Find Xbox user_games that could be linked to existing PSN game_titles
SELECT 
  ug_xbox.id as xbox_user_game_id,
  gt_xbox.name as xbox_game_name,
  gt_psn.id as psn_game_title_id,
  gt_psn.name as psn_game_name
FROM user_games ug_xbox
JOIN game_titles gt_xbox ON ug_xbox.game_title_id = gt_xbox.id
JOIN platforms p_xbox ON ug_xbox.platform_id = p_xbox.id
LEFT JOIN game_titles gt_psn ON LOWER(gt_xbox.name) = LOWER(gt_psn.name)
LEFT JOIN platforms p_psn ON gt_psn.platform_id = p_psn.id
WHERE p_xbox.code = 'XBOXONE'
  AND (p_psn.code LIKE 'PS%' OR p_psn.code IS NULL)
  AND gt_xbox.id != gt_psn.id
ORDER BY gt_xbox.name
LIMIT 20;

-- This shows which Xbox games could be merged with PSN games
-- Don't run the delete yet - let's see what we're dealing with first
