-- Apply outside a transaction to avoid blocking sync writes.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ua_user_earned_cover
ON public.user_achievements (user_id, earned_at)
INCLUDE (platform_id, platform_game_id, platform_achievement_id);
