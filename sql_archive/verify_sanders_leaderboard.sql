-- Confirm sanders.geoff leaderboard_cache is correct
SELECT 
  p.username,
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries,
  lc.last_updated
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE p.id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889';

-- Double check with manual calculation from user_progress
SELECT 
  SUM(current_score) as manual_total_from_user_progress
FROM user_progress
WHERE user_id = 'ca9dc5a7-34a6-4a71-8659-d28da82de889';
