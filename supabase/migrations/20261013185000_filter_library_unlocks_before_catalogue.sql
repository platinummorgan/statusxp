BEGIN;
DO $$ DECLARE fn record; definition text; BEGIN
 FOR fn IN SELECT oid,proname FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN('get_user_grouped_games','calculate_statusxp_with_stacks') LOOP
 definition:=pg_get_functiondef(fn.oid);
 definition:=replace(definition,'FROM public.user_achievement_unlocks ua','FROM user_unlocks ua');
 IF fn.proname='get_user_grouped_games' THEN
 definition:=replace(definition,'WITH user_games_base AS MATERIALIZED (','WITH user_unlocks AS MATERIALIZED (SELECT ul.user_id,ul.platform_id,ul.platform_game_id,ul.platform_achievement_id,ul.earned_at FROM public.user_achievement_unlocks ul WHERE ul.user_id=p_user_id), user_games_base AS MATERIALIZED (');
 ELSE
 definition:=replace(definition,'WITH game_raw_xp AS (','WITH user_unlocks AS MATERIALIZED (SELECT ul.user_id,ul.platform_id,ul.platform_game_id,ul.platform_achievement_id FROM public.user_achievement_unlocks ul WHERE ul.user_id=p_user_id), game_raw_xp AS (');
 END IF;
 EXECUTE definition;
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
