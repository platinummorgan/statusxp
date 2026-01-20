-- Find games with both null and non-null xbox_title_id (duplicates to clean up)
SELECT 
  gt.name,
  COUNT(*) as total_entries,
  COUNT(gt.xbox_title_id) as entries_with_id,
  COUNT(*) FILTER (WHERE gt.xbox_title_id IS NULL) as entries_without_id,
  STRING_AGG(DISTINCT gt.xbox_title_id, ', ') as title_ids,
  STRING_AGG(DISTINCT gt.id::text, ', ') as game_title_ids
FROM game_titles gt
WHERE gt.name IN (
  -- Find games that exist with both null and non-null xbox_title_id
  SELECT name 
  FROM game_titles 
  WHERE name IN (SELECT name FROM game_titles WHERE xbox_title_id IS NULL)
    AND name IN (SELECT name FROM game_titles WHERE xbox_title_id IS NOT NULL)
  GROUP BY name
)
GROUP BY gt.name
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;
