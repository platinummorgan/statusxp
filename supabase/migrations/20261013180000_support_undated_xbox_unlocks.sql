BEGIN;
SET LOCAL lock_timeout='10s';
CREATE TABLE public.user_undated_achievements (
 user_id uuid NOT NULL REFERENCES public.profiles_private(id) ON DELETE CASCADE,
 platform_id bigint NOT NULL CHECK(platform_id IN(10,11,12)),
 platform_game_id text NOT NULL,
 platform_achievement_id text NOT NULL,
 confirmed_at timestamptz NOT NULL DEFAULT now(),
 evidence_source text NOT NULL CHECK(evidence_source IN('xbox_live','openxbl')),
 PRIMARY KEY(user_id,platform_id,platform_game_id,platform_achievement_id),
 FOREIGN KEY(platform_id,platform_game_id,platform_achievement_id)
 REFERENCES public.achievements(platform_id,platform_game_id,platform_achievement_id) ON DELETE CASCADE
);
ALTER TABLE public.user_undated_achievements ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.user_undated_achievements TO anon,authenticated;
GRANT ALL ON public.user_undated_achievements TO service_role;
REVOKE INSERT,UPDATE,DELETE ON public.user_undated_achievements FROM anon,authenticated;
CREATE POLICY read_confirmed_undated_unlocks ON public.user_undated_achievements
FOR SELECT TO anon,authenticated USING(auth.uid()=user_id OR EXISTS(
 SELECT 1 FROM public.profiles p WHERE p.id=user_id AND p.show_on_leaderboard=true));
-- Use the safe public profile view in the existing read policy. Clients do not
-- have permission to read the underlying credential-bearing private table.
ALTER POLICY "Anyone can view achievements for leaderboard users" ON public.user_achievements
USING(EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=user_achievements.user_id AND p.show_on_leaderboard=true));

CREATE VIEW public.user_achievement_unlocks WITH(security_invoker=true) AS
SELECT d.user_id,d.platform_id,d.platform_game_id,d.platform_achievement_id,d.earned_at,true earned_date_known,a.rarity_global
FROM public.user_achievements d JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
UNION ALL
SELECT u.user_id,u.platform_id,u.platform_game_id,u.platform_achievement_id,NULL::timestamptz,false,a.rarity_global
FROM public.user_undated_achievements u JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id) WHERE NOT EXISTS(
 SELECT 1 FROM public.user_achievements d WHERE d.user_id=u.user_id AND d.platform_id=u.platform_id
 AND d.platform_game_id=u.platform_game_id AND d.platform_achievement_id=u.platform_achievement_id);
REVOKE ALL ON public.user_achievement_unlocks FROM anon,authenticated;
GRANT SELECT ON public.user_achievement_unlocks TO anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION statusxp_private.promote_known_unlock_date()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 DELETE FROM public.user_undated_achievements u WHERE u.user_id=NEW.user_id AND u.platform_id=NEW.platform_id
 AND u.platform_game_id=NEW.platform_game_id AND u.platform_achievement_id=NEW.platform_achievement_id;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION statusxp_private.promote_known_unlock_date() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER promote_known_unlock_date AFTER INSERT OR UPDATE ON public.user_achievements
FOR EACH ROW EXECUTE FUNCTION statusxp_private.promote_known_unlock_date();

-- The combined view exposes no credentials and enforces the original earned
-- record visibility rules. Dated APIs retain their non-null date contract.
DO $$ DECLARE fn record; definition text; BEGIN
 FOR fn IN SELECT oid,proname FROM pg_proc WHERE pronamespace='public'::regnamespace AND proname IN(
 'calculate_statusxp_with_stacks','refresh_statusxp_leaderboard_for_user','get_user_grouped_games') LOOP
 definition:=replace(replace(pg_get_functiondef(fn.oid),'public.user_achievements','public.user_achievement_unlocks'),
 'FROM user_achievements','FROM public.user_achievement_unlocks');
 IF fn.proname='get_user_grouped_games' THEN
  -- Library XP must use the same multiplier and per-game rounding as totals.
  definition:=replace(definition,
   'COALESCE(SUM(CASE WHEN a.include_in_score THEN a.base_status_xp ELSE 0 END), 0)::numeric AS statusxp',
   'COALESCE(SUM(CASE WHEN a.include_in_score THEN a.base_status_xp * COALESCE(a.rarity_multiplier,1.0) ELSE 0 END), 0)::integer::numeric AS statusxp');
 END IF;
 EXECUTE definition;
 END LOOP;
 EXECUTE 'CREATE OR REPLACE VIEW statusxp_private.statusxp_refresh_totals AS '||replace(pg_get_viewdef('statusxp_private.statusxp_refresh_totals'::regclass,true),
 'user_achievements','user_achievement_unlocks');
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
