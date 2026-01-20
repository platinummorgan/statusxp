-- Clean up old game_titles without npCommunicationId (pre-fix merged games)
-- These are the corrupted records from before we used npCommunicationId

-- Step 1: Find all game_titles without npCommunicationId that have duplicates
SELECT 
  g1.id as old_game_id,
  g1.name as game_name,
  g1.metadata->>'psn_np_communication_id' as old_np_id,
  g2.id as new_game_id,
  g2.metadata->>'psn_np_communication_id' as new_np_id,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = g1.id) as old_achievements,
  (SELECT COUNT(*) FROM achievements WHERE game_title_id = g2.id) as new_achievements
FROM game_titles g1
JOIN game_titles g2 ON LOWER(TRIM(g1.name)) = LOWER(TRIM(g2.name)) AND g1.id != g2.id
WHERE g1.metadata->>'psn_np_communication_id' IS NULL
  AND g2.metadata->>'psn_np_communication_id' IS NOT NULL
ORDER BY g1.name;

-- Step 2: Delete old game_titles without npCommunicationId that have newer versions
-- WARNING: This will cascade delete achievements, user_achievements, and user_games for old records
-- DO NOT RUN THIS YET - review the results from Step 1 first

-- DELETE FROM game_titles
-- WHERE metadata->>'psn_np_communication_id' IS NULL
--   AND name IN (
--     SELECT name FROM game_titles 
--     WHERE metadata->>'psn_np_communication_id' IS NOT NULL
--   );
