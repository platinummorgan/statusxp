-- Comprehensive audit of DanyGT37's data
-- User ID: 68de8222-9da5-4362-ac9b-96b302a7d455

-- ============================================================================
-- PROFILE INFO
-- ============================================================================
SELECT 
  'Profile Info' as section,
  display_name,
  psn_online_id,
  psn_account_id,
  steam_id,
  steam_display_name,
  show_on_leaderboard,
  created_at,
  updated_at
FROM profiles 
WHERE id = '68de8222-9da5-4362-ac9b-96b302a7d455';

-- ============================================================================
-- PSN DATA AUDIT
-- ============================================================================
-- PSN Games
SELECT 
  'PSN Games' as section,
  COUNT(*) as total_games,
  SUM(earned_trophies) as total_trophies_earned,
  SUM(total_trophies) as total_trophies_available,
  SUM(platinum_trophies) as platinums,
  SUM(gold_trophies) as golds,
  SUM(silver_trophies) as silvers,
  SUM(bronze_trophies) as bronzes,
  AVG(completion_percent) as avg_completion
FROM user_games
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND platform_id IN (1, 2, 5, 9); -- PS5, PS4, PS3, Vita

-- PSN Achievements (should be 0 before re-sync)
SELECT 
  'PSN Achievements in DB' as section,
  COUNT(*) as total_achievements_stored
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND a.platform = 'psn';

-- Top 5 PSN games by completion
SELECT 
  'Top PSN Games' as section,
  gt.name,
  ug.earned_trophies,
  ug.total_trophies,
  ug.completion_percent,
  ug.platinum_trophies,
  ug.last_trophy_earned_at
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND ug.platform_id IN (1, 2, 5, 9)
ORDER BY ug.completion_percent DESC
LIMIT 5;

-- ============================================================================
-- STEAM DATA AUDIT
-- ============================================================================
-- Steam Games
SELECT 
  'Steam Games' as section,
  COUNT(*) as total_games,
  SUM(earned_trophies) as total_achievements_earned,
  SUM(total_trophies) as total_achievements_available,
  AVG(completion_percent) as avg_completion
FROM user_games
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND platform_id = 4;

-- Steam Achievements (should now have some after partial sync)
SELECT 
  'Steam Achievements in DB' as section,
  COUNT(*) as total_achievements_stored
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND a.platform = 'steam';

-- Top 5 Steam games by completion
SELECT 
  'Top Steam Games' as section,
  gt.name,
  ug.earned_trophies,
  ug.total_trophies,
  ug.completion_percent,
  ug.last_trophy_earned_at
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
WHERE ug.user_id = '68de8222-9da5-4362-ac9b-96b302a7d455'
  AND ug.platform_id = 4
ORDER BY ug.completion_percent DESC
LIMIT 5;

-- ============================================================================
-- LEADERBOARD CACHE STATUS
-- ============================================================================
SELECT 
  'PSN Leaderboard Cache' as section,
  user_id,
  display_name,
  platinum_count,
  total_games,
  updated_at
FROM psn_leaderboard_cache
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';

SELECT 
  'Steam Leaderboard Cache' as section,
  user_id,
  display_name,
  achievement_count,
  total_games,
  updated_at
FROM steam_leaderboard_cache
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
