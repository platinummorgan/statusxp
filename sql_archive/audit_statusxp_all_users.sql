-- StatusXP Full Audit (All Users)
-- Purpose: Verify every user's StatusXP total matches canonical calculation
-- Safe, read-only diagnostics. Run in Supabase SQL editor.

-- ==========================================================
-- 0) Canonical total per user vs leaderboard_cache
-- ==========================================================
WITH canonical AS (
  SELECT
    p.id AS user_id,
    p.username,
    p.display_name,
    COALESCE(SUM(c.statusxp_effective), 0)::bigint AS canonical_total,
    COUNT(*) FILTER (WHERE c.statusxp_effective > 0) AS games_count
  FROM public.profiles p
  LEFT JOIN LATERAL public.calculate_statusxp_with_stacks(p.id) c ON true
  WHERE p.merged_into_user_id IS NULL
  GROUP BY p.id, p.username, p.display_name
),
cache AS (
  SELECT user_id, total_statusxp, total_game_entries, last_updated
  FROM public.leaderboard_cache
)
SELECT
  c.user_id,
  c.username,
  c.display_name,
  c.canonical_total,
  COALESCE(l.total_statusxp, 0) AS cached_total,
  (c.canonical_total - COALESCE(l.total_statusxp, 0)) AS delta,
  c.games_count AS canonical_games,
  COALESCE(l.total_game_entries, 0) AS cached_games,
  l.last_updated
FROM canonical c
LEFT JOIN cache l ON l.user_id = c.user_id
WHERE (c.canonical_total - COALESCE(l.total_statusxp, 0)) <> 0
ORDER BY ABS(c.canonical_total - COALESCE(l.total_statusxp, 0)) DESC;

-- ==========================================================
-- 1) Users missing from leaderboard_cache
-- ==========================================================
WITH canonical_users AS (
  SELECT p.id AS user_id
  FROM public.profiles p
  WHERE p.merged_into_user_id IS NULL
)
SELECT cu.user_id
FROM canonical_users cu
LEFT JOIN public.leaderboard_cache lc ON lc.user_id = cu.user_id
WHERE lc.user_id IS NULL
ORDER BY cu.user_id;

-- ==========================================================
-- 2) Users in leaderboard_cache with no earned achievements
-- ==========================================================
SELECT lc.user_id, lc.total_statusxp, lc.total_game_entries, lc.last_updated
FROM public.leaderboard_cache lc
LEFT JOIN public.user_achievements ua ON ua.user_id = lc.user_id
WHERE ua.user_id IS NULL
ORDER BY lc.total_statusxp DESC;

-- ==========================================================
-- 3) Orphaned user_achievements (no matching achievement row)
-- ==========================================================
SELECT
  ua.user_id,
  ua.platform_id,
  ua.platform_game_id,
  ua.platform_achievement_id,
  ua.earned_at
FROM public.user_achievements ua
LEFT JOIN public.achievements a
  ON a.platform_id = ua.platform_id
 AND a.platform_game_id = ua.platform_game_id
 AND a.platform_achievement_id = ua.platform_achievement_id
WHERE a.platform_achievement_id IS NULL
ORDER BY ua.earned_at DESC;

-- ==========================================================
-- 4) Achievements that should score but have missing base_status_xp
-- ==========================================================
SELECT
  a.platform_id,
  a.platform_game_id,
  a.platform_achievement_id,
  a.rarity_global,
  a.base_status_xp,
  a.include_in_score
FROM public.achievements a
WHERE a.include_in_score = true
  AND (a.base_status_xp IS NULL OR a.base_status_xp = 0)
ORDER BY a.platform_id, a.platform_game_id;

-- ==========================================================
-- 5) Rare/invalid rarity values on scoring achievements
-- ==========================================================
SELECT
  a.platform_id,
  a.platform_game_id,
  a.platform_achievement_id,
  a.rarity_global,
  a.base_status_xp
FROM public.achievements a
WHERE a.include_in_score = true
  AND (a.rarity_global IS NULL OR a.rarity_global < 0 OR a.rarity_global > 100)
ORDER BY a.platform_id, a.platform_game_id;

-- ==========================================================
-- 6) Per-user detail (enable when investigating a specific user)
-- ==========================================================
-- Replace :user_id with the target UUID
-- SELECT
--   c.platform_id,
--   c.platform_game_id,
--   c.game_name,
--   c.achievements_earned,
--   c.statusxp_raw,
--   c.stack_index,
--   c.stack_multiplier,
--   c.statusxp_effective
-- FROM public.calculate_statusxp_with_stacks(:user_id) c
-- ORDER BY c.statusxp_effective DESC;
