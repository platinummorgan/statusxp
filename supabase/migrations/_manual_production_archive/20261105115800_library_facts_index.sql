-- Run outside a transaction; these indexes do not block sync writes.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_achievements_library_facts
ON public.achievements(platform_id,platform_game_id,platform_achievement_id)
INCLUDE(score_value,base_status_xp,rarity_multiplier,rarity_global,include_in_score);
