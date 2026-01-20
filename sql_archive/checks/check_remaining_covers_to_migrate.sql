-- Check how many game covers still need migration
SELECT 
  COUNT(*) FILTER (WHERE cover_url IS NOT NULL AND proxied_cover_url IS NULL) as needs_migration,
  COUNT(*) FILTER (WHERE proxied_cover_url IS NOT NULL) as migrated,
  COUNT(*) FILTER (WHERE cover_url IS NULL) as no_cover,
  COUNT(*) as total_games
FROM game_titles;

-- Show some examples of games that need migration
SELECT id, name, cover_url
FROM game_titles
WHERE cover_url IS NOT NULL 
  AND proxied_cover_url IS NULL
LIMIT 20;
