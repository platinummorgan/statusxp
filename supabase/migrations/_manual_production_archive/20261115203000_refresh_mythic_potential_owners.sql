BEGIN;
SET LOCAL lock_timeout='5s';
CREATE OR REPLACE FUNCTION public.queue_xbox_mythic_score_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_TABLE_NAME='user_xbox_mythics' THEN
   IF TG_OP='INSERT' OR (NEW.platform_id,NEW.source_xuid,NEW.earned_at)
     IS DISTINCT FROM (OLD.platform_id,OLD.source_xuid,OLD.earned_at) THEN
     INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform)
       VALUES(NEW.user_id,'statusxp','xbox');
   END IF;
 ELSIF TG_OP='INSERT' OR NEW.base_status_xp IS DISTINCT FROM OLD.base_status_xp THEN
   -- Catalog XP also changes potential points for owners without an earned Mythic.
   INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform)
   SELECT owners.user_id,'statusxp','xbox' FROM (
     SELECT user_id FROM public.user_achievement_unlocks
       WHERE platform_id=NEW.platform_id AND platform_game_id=NEW.platform_game_id
     UNION SELECT user_id FROM public.user_xbox_mythics
       WHERE platform_id=NEW.platform_id AND platform_game_id=NEW.platform_game_id
   ) owners;
 END IF;
 RETURN NEW;
END;
$$;
DROP TRIGGER queue_mythic_rarity_refresh ON public.xbox_mythic_catalog;
CREATE TRIGGER queue_mythic_rarity_refresh AFTER INSERT OR UPDATE ON public.xbox_mythic_catalog
FOR EACH ROW EXECUTE FUNCTION public.queue_xbox_mythic_score_refresh();
COMMIT;
