CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_achievements_gold_keys
ON public.achievements(platform_id,platform_game_id,platform_achievement_id)
WHERE metadata->>'psn_trophy_type'='gold';
