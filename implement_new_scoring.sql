-- ============================================================================
-- New StatusXP Scoring: 1-10 points per achievement based on rarity
-- ============================================================================
-- Formula: round(clamp(10 * ln(1/p) / ln(1/0.0001), 1, 10))
-- Where p is clamped between 0.0001 (0.01%) and 0.90 (90%)

-- Step 1: Update all achievements with new scoring
UPDATE achievements
SET base_status_xp = ROUND(
  GREATEST(1, LEAST(10,
    10 * LN(1 / GREATEST(0.0001, LEAST(0.90, rarity_global / 100.0))) / LN(1 / 0.0001)
  ))
)::INTEGER
WHERE include_in_score = true;

-- Step 2: Verify the distribution
SELECT 
  base_status_xp as points,
  COUNT(*) as achievement_count,
  ROUND(MIN(rarity_global), 2) as min_rarity,
  ROUND(MAX(rarity_global), 2) as max_rarity
FROM achievements
WHERE include_in_score = true
GROUP BY base_status_xp
ORDER BY base_status_xp DESC;

-- Step 3: Rebuild leaderboard with new scoring
TRUNCATE TABLE leaderboard_cache;

INSERT INTO leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
SELECT
  ua.user_id,
  SUM(a.base_status_xp)::BIGINT as total_statusxp,
  COUNT(DISTINCT (ua.platform_id, ua.platform_game_id))::INTEGER as total_game_entries,
  NOW() as last_updated
FROM user_achievements ua
JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN profiles p ON p.id = ua.user_id
WHERE a.include_in_score = true
  AND p.merged_into_user_id IS NULL
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id
HAVING SUM(a.base_status_xp) > 0;

-- Step 4: Show top 10 leaderboard
SELECT 
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries,
  ROUND(lc.total_statusxp::NUMERIC / lc.total_game_entries, 1) as avg_points_per_game
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
ORDER BY lc.total_statusxp DESC
LIMIT 10;

-- Step 5: Your score
SELECT 
  p.display_name,
  lc.total_statusxp,
  lc.total_game_entries,
  ROUND(lc.total_statusxp::NUMERIC / lc.total_game_entries, 1) as avg_points_per_game
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE lc.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
