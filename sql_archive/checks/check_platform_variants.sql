-- Check if games with multiple xbox_title_ids are actually different platforms
-- This query shows games where we have MULTIPLE VALID xbox_title_ids (not NULL)
-- These are likely legitimate platform variants (Xbox 360, Xbox One, etc.)
SELECT 
  gt.name,
  COUNT(DISTINCT gt.xbox_title_id) FILTER (WHERE gt.xbox_title_id IS NOT NULL) as distinct_valid_ids,
  COUNT(*) FILTER (WHERE gt.xbox_title_id IS NULL) as null_count,
  STRING_AGG(DISTINCT gt.xbox_title_id, ', ' ORDER BY gt.xbox_title_id) as title_ids,
  STRING_AGG(DISTINCT gt.id::text, ', ' ORDER BY gt.id::text) as game_title_ids
FROM game_titles gt
WHERE gt.name IN (
  -- Games that appear in our duplicate list
  SELECT name 
  FROM game_titles 
  WHERE name IN (SELECT name FROM game_titles WHERE xbox_title_id IS NULL)
    AND name IN (SELECT name FROM game_titles WHERE xbox_title_id IS NOT NULL)
  GROUP BY name
)
GROUP BY gt.name
HAVING COUNT(DISTINCT gt.xbox_title_id) FILTER (WHERE gt.xbox_title_id IS NOT NULL) > 1
ORDER BY distinct_valid_ids DESC, gt.name;
