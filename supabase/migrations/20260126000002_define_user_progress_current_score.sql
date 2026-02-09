-- Migration: Define user_progress.current_score as platform-native score
-- Date: 2026-01-26

BEGIN;
COMMENT ON COLUMN public.user_progress.current_score IS
  'Platform-native score per game. Xbox: currentGamerscore from API. PSN: trophy points if available. Steam: 0 (no score system). Do NOT store StatusXP here.';
COMMIT;
