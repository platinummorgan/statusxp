-- Check where actual Xbox gamerscore is stored

-- 1. Check user_progress structure for Xbox - see if metadata has gamerscore
SELECT 
  platform_id,
  platform_game_id,
  current_score as statusxp_score,
  achievements_earned,
  total_achievements,
  metadata->>'gamerscore' as metadata_gamerscore,
  metadata->>'current_gamerscore' as metadata_current_gamerscore,
  metadata->>'max_gamerscore' as metadata_max_gamerscore,
  metadata
FROM user_progress
WHERE user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'  -- XxlmThumperxX
  AND platform_id IN (10, 11, 12)
ORDER BY statusxp_score DESC
LIMIT 10;

-- 2. Check if achievements have gamerscore in metadata
SELECT 
  platform_game_id,
  name,
  metadata->>'xbox_gamerscore' as xbox_gamerscore,
  metadata->>'gamerscore' as gamerscore,
  score_value,
  base_status_xp
FROM achievements
WHERE platform_id = 11
  AND platform_game_id = '80579825'  -- One of XxlmThumperxX's games
LIMIT 10;

-- 3. Sum actual gamerscore from achievements.score_value for one user
SELECT 
  SUM(a.score_value) as total_gamerscore_from_score_value,
  COUNT(*) as total_achievements
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND ua.platform_id IN (10, 11, 12);

-- 4. Compare: StatusXP vs actual Gamerscore for XxlmThumperxX
SELECT 
  'From user_progress.current_score (StatusXP)' as source,
  SUM(up.current_score) as total
FROM user_progress up
WHERE up.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND up.platform_id IN (10, 11, 12)
UNION ALL
SELECT 
  'From achievements.score_value (Gamerscore)' as source,
  SUM(a.score_value) as total
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id
  AND a.platform_game_id = ua.platform_game_id
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
  AND ua.platform_id IN (10, 11, 12);
