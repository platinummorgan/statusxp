-- Check Xbox sync results - did it write achievements for the 5 restored games?
-- User: Dexmorgan6981 (84b60ad6-cb2c-484f-8953-bf814551fd7a)

-- Baseline: 22 games, 309 achievements, 6,650 GS
-- Expected: 27 games, 317 achievements (+8), 6,775 GS (+125)

-- Test games removed:
-- 1. Exo One (1 achievement, 20 GS)
-- 2. NINJA GAIDEN Σ (1 achievement, 15 GS)
-- 3. Recompile (2 achievements, 30 GS)
-- 4. DEATHLOOP (2 achievements, 30 GS)
-- 5. PAC-MAN MUSEUM+ (2 achievements, 30 GS)

-- 1. Xbox sync status
SELECT 
  'Xbox Sync Status' as check,
  xbox_sync_status,
  xbox_sync_progress,
  xbox_sync_error,
  last_xbox_sync_at,
  (last_xbox_sync_at > NOW() - INTERVAL '5 minutes') as synced_recently
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;

-- 2. Game counts
SELECT 
  'Game Counts' as check,
  COUNT(*) FILTER (WHERE platform_id = 3) as xbox_games,
  SUM(xbox_current_gamerscore) FILTER (WHERE platform_id = 3) as current_gamerscore,
  SUM(xbox_achievements_earned) FILTER (WHERE platform_id = 3) as achievements_earned
FROM user_games
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;

-- 3. Achievement counts in user_achievements
SELECT 
  'Achievement Counts' as check,
  COUNT(*) FILTER (WHERE a.platform = 'xbox') as xbox_achievements,
  COUNT(*) as total_achievements
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid;

-- 4. Check if test games have achievements written
SELECT 
  'Test Games Achievement Status' as check,
  gt.name as game_name,
  ug.xbox_achievements_earned as api_earned,
  ug.xbox_current_gamerscore as gamerscore,
  COUNT(ua.achievement_id) as achievements_stored,
  CASE 
    WHEN ug.xbox_achievements_earned > 0 AND COUNT(ua.achievement_id) = 0 THEN '❌ MISSING'
    WHEN COUNT(ua.achievement_id) > 0 THEN '✅ WRITTEN'
    ELSE '⚪ NO DATA'
  END as status
FROM user_games ug
INNER JOIN game_titles gt ON gt.id = ug.game_title_id
LEFT JOIN achievements a ON a.game_title_id = gt.id AND a.platform = 'xbox'
LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = ug.user_id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid
AND ug.platform_id = 3
AND gt.name IN (
  'Exo One',
  'NINJA GAIDEN Σ',
  'Recompile',
  'DEATHLOOP',
  'PAC-MAN MUSEUM+'
)
GROUP BY gt.name, ug.xbox_achievements_earned, ug.xbox_current_gamerscore
ORDER BY gt.name;

-- 5. Summary comparison
SELECT 
  'Before vs After Summary' as check,
  'Before: 22 games, 309 achievements, 6,650 GS' as baseline,
  'Expected: 27 games, 317 achievements, 6,775 GS' as expected,
  (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid AND platform_id = 3)::text || ' games' as actual_games,
  (SELECT COUNT(*) FROM user_achievements ua INNER JOIN achievements a ON a.id = ua.achievement_id WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid AND a.platform = 'xbox')::text || ' achievements' as actual_achievements,
  (SELECT SUM(xbox_current_gamerscore) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid AND platform_id = 3)::text || ' GS' as actual_gamerscore;
