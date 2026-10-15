BEGIN;
DO $$ DECLARE definition text; BEGIN
 SELECT pg_get_functiondef(oid) INTO definition FROM pg_proc
 WHERE pronamespace='public'::regnamespace AND proname='get_user_grouped_games';
 -- Last played is useful activity information, but it is not an unlock date.
 definition:=replace(definition,
 '''last_trophy_earned_at'', COALESCE(ea.last_earned_at, ugb.last_played_at)',
 '''last_trophy_earned_at'', ea.last_earned_at');
 EXECUTE definition;
END $$;
COMMIT;
