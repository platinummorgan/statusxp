-- Fix Leaderboard Visibility After RLS
-- Date: 2026-01-30
-- Issue: Leaderboards only show current user after RLS enabled
-- Root Cause: user_achievements RLS blocks reading other users' data
-- Solution: Add policy to allow reading achievements for users on leaderboard

BEGIN;

-- Add policy: Anyone can read achievements for users who opted into leaderboards
CREATE POLICY "Anyone can view achievements for leaderboard users"
    ON public.user_achievements
    FOR SELECT
    TO authenticated, anon
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = user_achievements.user_id
            AND p.show_on_leaderboard = true
        )
    );

-- Add similar policy for user_progress (used by Xbox leaderboard)
CREATE POLICY "Anyone can view progress for leaderboard users"
    ON public.user_progress
    FOR SELECT
    TO authenticated, anon
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            WHERE p.id = user_progress.user_id
            AND p.show_on_leaderboard = true
        )
    );

COMMIT;

-- Verification: Check if leaderboards now show multiple users
-- SELECT COUNT(DISTINCT user_id) FROM xbox_leaderboard_cache;
-- Should show > 1 user if multiple people have Xbox achievements
