-- Migration: Fix Function Search Path Warnings
-- Purpose: Add search_path to functions to prevent search path confusion attacks
-- Created: 2025-12-18
-- Note: This migration only adds search_path configuration, does not modify function logic

-- ============================================================================
-- FIX FUNCTION SEARCH PATH WARNINGS
-- ============================================================================

-- Set search_path for all functions to prevent search path confusion attacks
-- Using 'public, pg_temp' allows functions to access public schema and temp tables

-- AI Credit Functions
ALTER FUNCTION public.consume_ai_credit SET search_path = 'public, pg_temp';
ALTER FUNCTION public.can_use_ai SET search_path = 'public, pg_temp';
ALTER FUNCTION public.add_ai_pack_credits SET search_path = 'public, pg_temp';

-- Sync Functions
ALTER FUNCTION public.can_user_sync SET search_path = 'public, pg_temp';
ALTER FUNCTION public.can_user_sync_psn SET search_path = 'public, pg_temp';

-- StatusXP Calculation
ALTER FUNCTION public.calculate_user_achievement_statusxp SET search_path = 'public, pg_temp';
ALTER FUNCTION public.calculate_user_game_statusxp SET search_path = 'public, pg_temp';

-- Achievement Rarity Functions
ALTER FUNCTION public.recalculate_achievement_rarity SET search_path = 'public, pg_temp';
ALTER FUNCTION public.trigger_update_achievement_rarity SET search_path = 'public, pg_temp';

-- Achievement Check Functions
ALTER FUNCTION public.check_game_hopper SET search_path = 'public, pg_temp';
ALTER FUNCTION public.get_most_time_sunk_game SET search_path = 'public, pg_temp';
ALTER FUNCTION public.check_spike_week SET search_path = 'public, pg_temp';
ALTER FUNCTION public.check_power_session SET search_path = 'public, pg_temp';
ALTER FUNCTION public.check_big_comeback SET search_path = 'public, pg_temp';
ALTER FUNCTION public.check_closer SET search_path = 'public, pg_temp';
ALTER FUNCTION public.check_glow_up SET search_path = 'public, pg_temp';
ALTER FUNCTION public.check_genre_diversity SET search_path = 'public, pg_temp';

-- Update Triggers
ALTER FUNCTION public.update_updated_at_column SET search_path = 'public, pg_temp';
ALTER FUNCTION public.update_flex_room_data_updated_at SET search_path = 'public, pg_temp';

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON FUNCTION public.consume_ai_credit IS 'Consumes AI credit - search_path set to prevent attacks';
COMMENT ON FUNCTION public.can_use_ai IS 'Checks AI credit availability - search_path set to prevent attacks';
COMMENT ON FUNCTION public.add_ai_pack_credits IS 'Adds purchased AI credits - search_path set to prevent attacks';

-- ============================================================================
-- NOTES
-- ============================================================================
-- This migration is completely safe:
-- - Only adds search_path configuration to existing functions
-- - Does not modify function logic or signatures
-- - Prevents search path confusion attacks
-- - If a function doesn't exist, ALTER FUNCTION will fail but won't break anything
