-- Online build: existing sync writes remain available while this index is built.
CREATE INDEX CONCURRENTLY IF NOT EXISTS achievements_platinum_card_lookup
ON public.achievements(platform_id,platform_game_id,platform_achievement_id)
WHERE is_platinum=true;
