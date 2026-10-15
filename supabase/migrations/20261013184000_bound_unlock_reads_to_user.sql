BEGIN;
-- Fetch rarity only when a caller asks for it. Joining the complete catalogue
-- inside each UNION branch caused a catalogue-first plan for user libraries.
CREATE OR REPLACE VIEW public.user_achievement_unlocks WITH(security_invoker=true) AS
SELECT d.user_id,d.platform_id,d.platform_game_id,d.platform_achievement_id,d.earned_at,true earned_date_known,
 (SELECT a.rarity_global FROM public.achievements a WHERE a.platform_id=d.platform_id AND a.platform_game_id=d.platform_game_id AND a.platform_achievement_id=d.platform_achievement_id) rarity_global
FROM public.user_achievements d
UNION ALL
SELECT u.user_id,u.platform_id,u.platform_game_id,u.platform_achievement_id,NULL::timestamptz,false,
 (SELECT a.rarity_global FROM public.achievements a WHERE a.platform_id=u.platform_id AND a.platform_game_id=u.platform_game_id AND a.platform_achievement_id=u.platform_achievement_id)
FROM public.user_undated_achievements u WHERE NOT EXISTS(
 SELECT 1 FROM public.user_achievements d WHERE d.user_id=u.user_id AND d.platform_id=u.platform_id
 AND d.platform_game_id=u.platform_game_id AND d.platform_achievement_id=u.platform_achievement_id);
NOTIFY pgrst,'reload schema';
COMMIT;
