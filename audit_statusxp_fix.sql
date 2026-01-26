-- StatusXP Fix Script (Safe Updates)
-- Purpose: Recompute base_status_xp where possible and rebuild leaderboard_cache for ALL users.
-- Run in Supabase SQL editor. Review comments before running.

-- ==========================================================
-- 1) Recompute base_status_xp from rarity_global (only when known)
-- ==========================================================
-- Optional: Default missing Xbox rarities to 50% (if XBL has no data)
-- This applies only to Xbox platforms and keeps Steam/PSN nulls unchanged.
-- Uncomment to enable.
UPDATE public.achievements
SET rarity_global = 50
WHERE include_in_score = true
  AND rarity_global IS NULL
  AND platform_id IN (10, 11, 12);

-- This does NOT change rows where rarity_global is NULL.
UPDATE public.achievements
SET base_status_xp = ROUND(
  LEAST(12, GREATEST(0.5, 0.5 + 11.5 * POWER(1 - (rarity_global / 100.0), 3)))
, 2)
WHERE include_in_score = true
  AND rarity_global IS NOT NULL
  AND rarity_global BETWEEN 0 AND 100;

-- Optional: ensure non-scoring achievements stay zero
-- UPDATE public.achievements
-- SET base_status_xp = 0
-- WHERE include_in_score = false;

-- ==========================================================
-- 2) Rebuild leaderboard_cache for ALL users
-- ==========================================================
-- NOTE: This intentionally ignores profiles.show_on_leaderboard so every user
-- has a cached StatusXP total for dashboards and services that depend on it.
TRUNCATE public.leaderboard_cache;

INSERT INTO public.leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
SELECT
  p.id AS user_id,
  COALESCE(game_totals.total_statusxp, 0) AS total_statusxp,
  COALESCE(game_totals.total_games, 0) AS total_game_entries,
  NOW() AS last_updated
FROM public.profiles p
LEFT JOIN LATERAL (
  SELECT
    COUNT(*)::integer AS total_games,
    COALESCE(SUM(statusxp_effective), 0)::bigint AS total_statusxp
  FROM public.calculate_statusxp_with_stacks(p.id)
) game_totals ON true
WHERE p.merged_into_user_id IS NULL;

-- ==========================================================
-- 3) Post-check: confirm no deltas
-- ==========================================================
WITH canonical AS (
  SELECT
    p.id AS user_id,
    COALESCE(SUM(c.statusxp_effective), 0)::bigint AS canonical_total,
    COUNT(*) FILTER (WHERE c.statusxp_effective > 0) AS games_count
  FROM public.profiles p
  LEFT JOIN LATERAL public.calculate_statusxp_with_stacks(p.id) c ON true
  WHERE p.merged_into_user_id IS NULL
  GROUP BY p.id
),
cache AS (
  SELECT user_id, total_statusxp, total_game_entries
  FROM public.leaderboard_cache
)
SELECT
  c.user_id,
  c.canonical_total,
  COALESCE(l.total_statusxp, 0) AS cached_total,
  (c.canonical_total - COALESCE(l.total_statusxp, 0)) AS delta,
  c.games_count AS canonical_games,
  COALESCE(l.total_game_entries, 0) AS cached_games
FROM canonical c
LEFT JOIN cache l ON l.user_id = c.user_id
WHERE (c.canonical_total - COALESCE(l.total_statusxp, 0)) <> 0
ORDER BY ABS(c.canonical_total - COALESCE(l.total_statusxp, 0)) DESC;

-- ==========================================================
-- 4) Identify achievements still missing rarity_global (for backfill)
-- ==========================================================
SELECT
  a.platform_id,
  a.platform_game_id,
  COUNT(*) AS missing_rarity_count
FROM public.achievements a
WHERE a.include_in_score = true
  AND a.rarity_global IS NULL
GROUP BY a.platform_id, a.platform_game_id
ORDER BY missing_rarity_count DESC;