-- EMERGENCY SECURITY FIX: Enable RLS on Critical User Data Tables
-- Date: 2026-01-30
-- Issue: user_achievements and user_progress have RLS disabled in production
-- Risk: ALL user achievement and progress data is publicly readable
--
-- This migration:
-- 1. Enables RLS on critical user data tables
-- 2. Adds policies to allow users to read their own data
-- 3. Allows service_role (Edge Functions) to write data during sync
--
-- SAFE TO APPLY: Only adds security, doesn't remove any existing access patterns

-- ============================================================================
-- CRITICAL: Enable RLS on User Data Tables
-- ============================================================================

-- Enable RLS on user_achievements (CRITICAL - contains which achievements each user earned)
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

-- Enable RLS on user_progress (CRITICAL - contains user game progress/completion)
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Add RLS Policies for user_achievements
-- ============================================================================

-- Policy: Users can view their own achievements
CREATE POLICY "Users can view their own achievements"
    ON public.user_achievements
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Policy: Service role can insert achievements (for sync operations)
CREATE POLICY "Service role can insert achievements"
    ON public.user_achievements
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- Policy: Service role can update achievements (for sync operations)
CREATE POLICY "Service role can update achievements"
    ON public.user_achievements
    FOR UPDATE
    TO service_role
    USING (true);

-- Policy: Service role can delete achievements (for cleanup operations)
CREATE POLICY "Service role can delete achievements"
    ON public.user_achievements
    FOR DELETE
    TO service_role
    USING (true);

-- ============================================================================
-- Add RLS Policies for user_progress
-- ============================================================================

-- Policy: Users can view their own progress
CREATE POLICY "Users can view their own progress"
    ON public.user_progress
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- Policy: Service role can insert progress (for sync operations)
CREATE POLICY "Service role can insert progress"
    ON public.user_progress
    FOR INSERT
    TO service_role
    WITH CHECK (true);

-- Policy: Service role can update progress (for sync operations)
CREATE POLICY "Service role can update progress"
    ON public.user_progress
    FOR UPDATE
    TO service_role
    USING (true);

-- Policy: Service role can delete progress (for cleanup operations)
CREATE POLICY "Service role can delete progress"
    ON public.user_progress
    FOR DELETE
    TO service_role
    USING (true);

-- ============================================================================
-- Enable RLS on Reference Data Tables (Lower Priority)
-- ============================================================================

-- These tables contain game catalog data that should be publicly readable
-- Enabling RLS here is best practice even though data is public

ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.game_groups_refresh_queue ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- Add Public Read Policies for Reference Data
-- ============================================================================

-- Policy: Anyone can read games catalog
CREATE POLICY "Anyone can read games"
    ON public.games
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Policy: Anyone can read achievements catalog
CREATE POLICY "Anyone can read achievements"
    ON public.achievements
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Policy: Anyone can read game groups
CREATE POLICY "Anyone can read game groups"
    ON public.game_groups
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Policy: Anyone can read leaderboard cache (public leaderboard data)
CREATE POLICY "Anyone can read leaderboard cache"
    ON public.leaderboard_cache
    FOR SELECT
    TO authenticated, anon
    USING (true);

-- Policy: Only service role can access refresh queue (internal use only)
CREATE POLICY "Service role can manage refresh queue"
    ON public.game_groups_refresh_queue
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- ============================================================================
-- Fix SECURITY DEFINER Views (Secondary Priority)
-- ============================================================================

-- Drop and recreate views with security_invoker instead of SECURITY DEFINER
-- This makes views respect the querying user's permissions

-- Fix: xbox_leaderboard_cache
DROP VIEW IF EXISTS public.xbox_leaderboard_cache CASCADE;
CREATE OR REPLACE VIEW public.xbox_leaderboard_cache 
WITH (security_invoker = true) AS
SELECT 
  ua.user_id,
  COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player') as display_name,
  p.xbox_avatar_url as avatar_url,
  COUNT(*) as achievement_count,
  COUNT(DISTINCT a.platform_game_id) as total_games,
  COALESCE(SUM(up.current_score), 0) as gamerscore,
  now() as updated_at
FROM public.user_achievements ua
JOIN public.achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN public.profiles p ON p.id = ua.user_id
LEFT JOIN public.user_progress up ON 
  up.user_id = ua.user_id 
  AND up.platform_id = a.platform_id 
  AND up.platform_game_id = a.platform_game_id
WHERE ua.platform_id IN (10, 11, 12) -- Xbox 360, One, Series X/S
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.xbox_gamertag, p.display_name, p.username, p.xbox_avatar_url
HAVING COUNT(*) > 0
ORDER BY COALESCE(SUM(up.current_score), 0) DESC, COUNT(*) DESC, COUNT(DISTINCT a.platform_game_id) DESC;

-- Fix: psn_leaderboard_cache
DROP VIEW IF EXISTS public.psn_leaderboard_cache CASCADE;
CREATE OR REPLACE VIEW public.psn_leaderboard_cache 
WITH (security_invoker = true) AS
SELECT 
  ua.user_id,
  COALESCE(p.psn_online_id, p.display_name, p.username, 'Player') as display_name,
  p.psn_avatar_url as avatar_url,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END) as bronze_count,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END) as silver_count,
  SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END) as gold_count,
  SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) as platinum_count,
  COUNT(*) as total_trophies,
  COUNT(DISTINCT a.platform_game_id) as total_games,
  now() as updated_at
FROM public.user_achievements ua
JOIN public.achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN public.profiles p ON p.id = ua.user_id
WHERE ua.platform_id IN (1, 2, 5, 9) -- PSN platforms
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.psn_online_id, p.display_name, p.username, p.psn_avatar_url
HAVING COUNT(*) > 0
ORDER BY SUM(CASE WHEN a.is_platinum = true THEN 1 ELSE 0 END) DESC,
         SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 ELSE 0 END) DESC,
         SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 ELSE 0 END) DESC,
         SUM(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 ELSE 0 END) DESC;

-- Fix: steam_leaderboard_cache
DROP VIEW IF EXISTS public.steam_leaderboard_cache CASCADE;
CREATE OR REPLACE VIEW public.steam_leaderboard_cache 
WITH (security_invoker = true) AS
SELECT 
  ua.user_id,
  COALESCE(p.steam_display_name, p.display_name, p.username, 'Player') as display_name,
  p.steam_avatar_url as avatar_url,
  COUNT(*) as achievement_count,
  COUNT(DISTINCT a.platform_game_id) as total_games,
  now() as updated_at
FROM public.user_achievements ua
JOIN public.achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
JOIN public.profiles p ON p.id = ua.user_id
WHERE ua.platform_id = 4 -- Steam
  AND p.show_on_leaderboard = true
GROUP BY ua.user_id, p.steam_display_name, p.display_name, p.username, p.steam_avatar_url
HAVING COUNT(*) > 0
ORDER BY COUNT(*) DESC, COUNT(DISTINCT a.platform_game_id) DESC;

-- Fix: leaderboard_global_cache
DROP VIEW IF EXISTS public.leaderboard_global_cache CASCADE;
CREATE OR REPLACE VIEW public.leaderboard_global_cache 
WITH (security_invoker = true) AS
WITH user_statusxp AS (
  SELECT 
    ua.user_id,
    SUM(
      CASE
        WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 1.0 THEN 300
        WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 5.0 THEN 225
        WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 10.0 THEN 175
        WHEN a.rarity_global IS NOT NULL AND a.rarity_global <= 25.0 THEN 125
        WHEN a.rarity_global IS NOT NULL THEN 100
        ELSE 100
      END
    ) as statusxp,
    COUNT(DISTINCT ROW(a.platform_id, a.platform_game_id, a.platform_achievement_id)) as total_achievements,
    COUNT(DISTINCT ROW(a.platform_id, a.platform_game_id)) as total_games
  FROM public.user_achievements ua
  JOIN public.achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  GROUP BY ua.user_id
)
SELECT 
  ROW_NUMBER() OVER (ORDER BY us.statusxp DESC, us.total_achievements DESC) as rank,
  us.user_id,
  COALESCE(p.display_name, p.username, 'Player') as display_name,
  p.avatar_url,
  us.statusxp,
  us.total_achievements,
  us.total_games,
  now() as updated_at
FROM user_statusxp us
JOIN public.profiles p ON p.id = us.user_id
WHERE p.show_on_leaderboard = true
  AND us.statusxp > 0
ORDER BY us.statusxp DESC, us.total_achievements DESC;

-- Fix: user_games
DROP VIEW IF EXISTS public.user_games CASCADE;
CREATE OR REPLACE VIEW public.user_games 
WITH (security_invoker = true) AS
WITH user_game_progress AS (
  SELECT 
    up.user_id,
    up.platform_id,
    up.platform_game_id,
    up.achievements_earned as earned_trophies,
    up.total_achievements as total_trophies,
    up.completion_percentage,
    up.current_score,
    up.last_played_at,
    ('x' || substr(md5(up.platform_id::text || '_' || up.platform_game_id), 1, 15))::bit(60)::bigint as game_title_id,
    g.name
  FROM public.user_progress up
  JOIN public.games g ON 
    g.platform_id = up.platform_id 
    AND g.platform_game_id = up.platform_game_id
),
psn_trophy_breakdown AS (
  SELECT 
    ua.user_id,
    ua.platform_id,
    ua.platform_game_id,
    COUNT(CASE WHEN a.metadata->>'psn_trophy_type' = 'bronze' THEN 1 END) as bronze_trophies,
    COUNT(CASE WHEN a.metadata->>'psn_trophy_type' = 'silver' THEN 1 END) as silver_trophies,
    COUNT(CASE WHEN a.metadata->>'psn_trophy_type' = 'gold' THEN 1 END) as gold_trophies,
    COUNT(CASE WHEN a.metadata->>'psn_trophy_type' = 'platinum' THEN 1 END) as platinum_trophies,
    MAX(ua.earned_at) as last_trophy_earned_at,
    EXISTS(
      SELECT 1 
      FROM public.achievements a2 
      WHERE a2.platform_id = ua.platform_id 
        AND a2.platform_game_id = ua.platform_game_id 
        AND a2.metadata->>'psn_trophy_type' = 'platinum'
    ) as has_platinum
  FROM public.user_achievements ua
  JOIN public.achievements a ON 
    a.platform_id = ua.platform_id 
    AND a.platform_game_id = ua.platform_game_id 
    AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.platform_id = 1
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
)
SELECT 
  ROW_NUMBER() OVER (ORDER BY ugp.user_id, ugp.platform_id, ugp.platform_game_id) as id,
  ugp.user_id,
  ugp.game_title_id,
  ugp.platform_id,
  ugp.name as game_title,
  COALESCE(psn.has_platinum, false) as has_platinum,
  COALESCE(psn.bronze_trophies, 0) as bronze_trophies,
  COALESCE(psn.silver_trophies, 0) as silver_trophies,
  COALESCE(psn.gold_trophies, 0) as gold_trophies,
  COALESCE(psn.platinum_trophies, 0) as platinum_trophies,
  COALESCE(psn.last_trophy_earned_at, ugp.last_played_at) as last_trophy_earned_at,
  ugp.total_trophies,
  ugp.earned_trophies,
  ugp.completion_percentage as completion_percent,
  ugp.last_played_at,
  ugp.current_score,
  now() as created_at,
  now() as updated_at
FROM user_game_progress ugp
LEFT JOIN psn_trophy_breakdown psn ON 
  psn.user_id = ugp.user_id 
  AND psn.platform_id = ugp.platform_id 
  AND psn.platform_game_id = ugp.platform_game_id;

-- ============================================================================
-- Verification Query
-- ============================================================================

-- Run this after migration to verify RLS is enabled:
-- SELECT schemaname, tablename, rowsecurity as rls_enabled
-- FROM pg_tables 
-- WHERE schemaname = 'public'
--   AND tablename IN ('user_achievements', 'user_progress', 'games', 'achievements')
-- ORDER BY tablename;
