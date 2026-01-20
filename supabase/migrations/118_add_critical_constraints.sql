-- Migration 118: Add Critical Uniqueness Constraints
-- Based on external analysis - prevents duplicate earned events
-- This is THE most important fix to stop data drift

-- ============================================================================
-- PHASE 1: Add uniqueness constraints to earned events
-- ============================================================================

-- Prevent duplicate earned trophies
-- This stops PSN sync from creating duplicate trophy records
ALTER TABLE public.user_trophies
  ADD CONSTRAINT user_trophies_user_trophy_unique UNIQUE (user_id, trophy_id);

-- Prevent duplicate earned achievements  
-- This stops Xbox/Steam sync from creating duplicate achievement records
ALTER TABLE public.user_achievements
  ADD CONSTRAINT user_achievements_user_achievement_unique UNIQUE (user_id, achievement_id);

-- Prevent duplicate user_games entries
-- This stops the same game from being counted multiple times per user+platform
ALTER TABLE public.user_games
  ADD CONSTRAINT user_games_unique UNIQUE (user_id, game_title_id, platform_id);

-- ============================================================================
-- PHASE 2: Add missing foreign key indexes (stops disk IO bleeding)
-- ============================================================================

-- user_trophies indexes (if not already exist from Migration 116)
CREATE INDEX IF NOT EXISTS idx_user_trophies_user_id 
  ON public.user_trophies(user_id);
CREATE INDEX IF NOT EXISTS idx_user_trophies_trophy_id 
  ON public.user_trophies(trophy_id);

-- user_achievements indexes (if not already exist from Migration 116)
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id 
  ON public.user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement_id 
  ON public.user_achievements(achievement_id);

-- Catalog table indexes for joins
CREATE INDEX IF NOT EXISTS idx_trophies_game_title_id 
  ON public.trophies(game_title_id);
CREATE INDEX IF NOT EXISTS idx_achievements_game_title_id 
  ON public.achievements(game_title_id);

-- user_games indexes (if not already exist from Migration 116)
CREATE INDEX IF NOT EXISTS idx_user_games_user_id 
  ON public.user_games(user_id);
CREATE INDEX IF NOT EXISTS idx_user_games_user_platform 
  ON public.user_games(user_id, platform_id);
CREATE INDEX IF NOT EXISTS idx_user_games_game_title 
  ON public.user_games(game_title_id);

-- ============================================================================
-- PHASE 3: Add indexes for earned_at timestamps (common filter/sort)
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_user_trophies_earned_at 
  ON public.user_trophies(earned_at) WHERE earned_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_achievements_earned_at 
  ON public.user_achievements(earned_at) WHERE earned_at IS NOT NULL;

-- ============================================================================
-- NOTES
-- ============================================================================
-- 
-- WHY THIS MATTERS:
-- - Without UNIQUE constraints, sync jobs can silently create duplicates
-- - Duplicates inflate all dashboard numbers (trophies, achievements, games)
-- - Missing FK indexes cause full table scans = disk IO budget explosion
--
-- WHAT THIS FIXES:
-- - Duplicate earned trophies/achievements (root cause of "numbers wrong")
-- - Duplicate user_games entries (explains Gordon's 66-game inflation)
-- - Sequential scans on joins (50-70% disk IO reduction expected)
--
-- SAFE TO RUN:
-- - If duplicates exist, this will fail with constraint violation
-- - In that case, we need to deduplicate first (see next migration)
-- - Indexes are IF NOT EXISTS, safe to re-run
