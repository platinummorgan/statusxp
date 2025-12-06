-- Delete Xbox game titles that have no achievement data
-- (These are games that were synced but user has 0 progress)

DELETE FROM game_titles
WHERE (xbox_max_gamerscore IS NULL OR xbox_max_gamerscore = 0)
  AND (xbox_total_achievements IS NULL OR xbox_total_achievements = 0)
  AND xbox_title_id IS NOT NULL;

-- Note: This will also cascade delete any related records if you have foreign keys set up
