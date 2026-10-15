BEGIN;
DO $$ BEGIN
 EXECUTE replace(pg_get_functiondef('public.calculate_statusxp_with_stacks(uuid)'::regprocedure),
 'SELECT user_id,platform_id,platform_game_id,platform_achievement_id FROM public.user_achievement_unlocks WHERE user_id=p_user_id',
 'SELECT ul.user_id,ul.platform_id,ul.platform_game_id,ul.platform_achievement_id FROM public.user_achievement_unlocks ul WHERE ul.user_id=p_user_id');
END $$;
COMMIT;
