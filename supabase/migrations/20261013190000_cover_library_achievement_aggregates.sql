-- Production index was created CONCURRENTLY outside a transaction.
-- Use regular index creation here for transactional migration runners.
-- Cover library aggregates so large libraries do not fetch a heap page for
-- every achievement while calculating counts, trophy types and StatusXP.
CREATE INDEX IF NOT EXISTS idx_achievements_library_cover
ON public.achievements(platform_id,platform_game_id,platform_achievement_id)
INCLUDE(score_value,rarity_global,include_in_score,base_status_xp,rarity_multiplier,metadata);
ANALYZE public.achievements;
