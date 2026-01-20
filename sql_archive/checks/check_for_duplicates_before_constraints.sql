-- Check for existing duplicates BEFORE adding unique constraints
-- If any of these return rows, we need to deduplicate first

-- Check user_trophies for duplicates
SELECT 
  user_id,
  trophy_id,
  COUNT(*) as duplicate_count,
  STRING_AGG(id::text, ', ') as duplicate_ids,
  MIN(earned_at) as first_earned,
  MAX(earned_at) as last_earned
FROM user_trophies
GROUP BY user_id, trophy_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- Check user_achievements for duplicates
SELECT 
  user_id,
  achievement_id,
  COUNT(*) as duplicate_count,
  STRING_AGG(id::text, ', ') as duplicate_ids,
  MIN(earned_at) as first_earned,
  MAX(earned_at) as last_earned
FROM user_achievements
GROUP BY user_id, achievement_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- Check user_games for duplicates
SELECT 
  user_id,
  game_title_id,
  platform_id,
  COUNT(*) as duplicate_count,
  STRING_AGG(id::text, ', ') as duplicate_ids,
  STRING_AGG(xbox_current_gamerscore::text, ', ') as gamerscores,
  STRING_AGG(psn_progress_percent::text, ', ') as psn_progress
FROM user_games
GROUP BY user_id, game_title_id, platform_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

-- Summary counts
SELECT 
  'user_trophies' as table_name,
  COUNT(*) as total_rows,
  COUNT(DISTINCT (user_id, trophy_id)) as unique_combinations,
  COUNT(*) - COUNT(DISTINCT (user_id, trophy_id)) as duplicates
FROM user_trophies
UNION ALL
SELECT 
  'user_achievements',
  COUNT(*),
  COUNT(DISTINCT (user_id, achievement_id)),
  COUNT(*) - COUNT(DISTINCT (user_id, achievement_id))
FROM user_achievements
UNION ALL
SELECT 
  'user_games',
  COUNT(*),
  COUNT(DISTINCT (user_id, game_title_id, platform_id)),
  COUNT(*) - COUNT(DISTINCT (user_id, game_title_id, platform_id))
FROM user_games;
