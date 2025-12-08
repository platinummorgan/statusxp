-- Rollback script to remove meta-achievements tables
-- Run this in the Invoice_automater database to undo the migration

-- Drop policies first
DROP POLICY IF EXISTS "Users can upsert their own selected title" ON public.user_selected_title;
DROP POLICY IF EXISTS "Users can view their own selected title" ON public.user_selected_title;
DROP POLICY IF EXISTS "Users can update their own meta achievements" ON public.user_meta_achievements;
DROP POLICY IF EXISTS "Users can unlock their own meta achievements" ON public.user_meta_achievements;
DROP POLICY IF EXISTS "Users can view their own meta achievements" ON public.user_meta_achievements;
DROP POLICY IF EXISTS "Anyone can view meta achievements" ON public.meta_achievements;

-- Drop indexes
DROP INDEX IF EXISTS public.idx_meta_achievements_category;
DROP INDEX IF EXISTS public.idx_user_meta_achievements_achievement_id;
DROP INDEX IF EXISTS public.idx_user_meta_achievements_user_id;

-- Drop tables (in reverse order due to foreign key constraints)
DROP TABLE IF EXISTS public.user_selected_title;
DROP TABLE IF EXISTS public.user_meta_achievements;
DROP TABLE IF EXISTS public.meta_achievements;
