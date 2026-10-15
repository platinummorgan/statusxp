BEGIN;
SET LOCAL lock_timeout='5s';
-- No historical identity is inferred. New verified imports provide provenance.
ALTER TABLE public.user_achievements ADD COLUMN xbox_source_xuid text;
ALTER TABLE public.user_undated_achievements ADD COLUMN xbox_source_xuid text;
CREATE OR REPLACE FUNCTION statusxp_private.verify_xbox_import_identity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE source_xuid text; linked_xuid text;
BEGIN
 IF NEW.platform_id NOT IN(10,11,12) THEN RETURN NEW; END IF;
 IF TG_TABLE_NAME='user_progress' THEN source_xuid:=NEW.metadata->>'xbox_source_xuid';
 ELSE source_xuid:=NEW.xbox_source_xuid; END IF;
 IF source_xuid IS NULL THEN RETURN NEW; END IF;
 SELECT xbox_xuid INTO linked_xuid FROM public.profiles_private WHERE id=NEW.user_id FOR SHARE;
 IF source_xuid IS DISTINCT FROM linked_xuid THEN
  RAISE EXCEPTION 'Xbox connection changed during this import. Reconnect the original Xbox account and retry.' USING ERRCODE='55000';
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION statusxp_private.verify_xbox_import_identity() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER verify_xbox_import_identity BEFORE INSERT OR UPDATE ON public.user_achievements
FOR EACH ROW EXECUTE FUNCTION statusxp_private.verify_xbox_import_identity();
CREATE TRIGGER verify_xbox_import_identity BEFORE INSERT OR UPDATE ON public.user_undated_achievements
FOR EACH ROW EXECUTE FUNCTION statusxp_private.verify_xbox_import_identity();
CREATE TRIGGER verify_xbox_import_identity BEFORE INSERT OR UPDATE ON public.user_progress
FOR EACH ROW EXECUTE FUNCTION statusxp_private.verify_xbox_import_identity();
NOTIFY pgrst,'reload schema';
COMMIT;
