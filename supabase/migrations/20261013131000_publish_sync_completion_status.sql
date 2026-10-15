BEGIN;
CREATE TABLE public.profile_sync_notifications(
 user_id uuid PRIMARY KEY REFERENCES public.profiles_private(id) ON DELETE CASCADE,
 psn_sync_status text,xbox_sync_status text,steam_sync_status text,
 last_psn_sync_at timestamptz,last_xbox_sync_at timestamptz,last_steam_sync_at timestamptz
);
ALTER TABLE public.profile_sync_notifications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.profile_sync_notifications FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.profile_sync_notifications TO authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.profile_sync_notifications TO service_role;
CREATE POLICY owner_reads_sync_notifications ON public.profile_sync_notifications FOR SELECT TO authenticated
 USING((SELECT auth.uid())=user_id);
CREATE FUNCTION statusxp_private.publish_profile_sync_status() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO public.profile_sync_notifications VALUES(NEW.id,NEW.psn_sync_status,NEW.xbox_sync_status,NEW.steam_sync_status,NEW.last_psn_sync_at,NEW.last_xbox_sync_at,NEW.last_steam_sync_at)
 ON CONFLICT(user_id) DO UPDATE SET psn_sync_status=EXCLUDED.psn_sync_status,xbox_sync_status=EXCLUDED.xbox_sync_status,steam_sync_status=EXCLUDED.steam_sync_status,last_psn_sync_at=EXCLUDED.last_psn_sync_at,last_xbox_sync_at=EXCLUDED.last_xbox_sync_at,last_steam_sync_at=EXCLUDED.last_steam_sync_at;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION statusxp_private.publish_profile_sync_status() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER publish_profile_sync_insert AFTER INSERT ON public.profiles_private FOR EACH ROW EXECUTE FUNCTION statusxp_private.publish_profile_sync_status();
CREATE TRIGGER publish_profile_sync_update AFTER UPDATE ON public.profiles_private FOR EACH ROW
 WHEN(OLD.psn_sync_status IS DISTINCT FROM NEW.psn_sync_status OR OLD.xbox_sync_status IS DISTINCT FROM NEW.xbox_sync_status OR OLD.steam_sync_status IS DISTINCT FROM NEW.steam_sync_status OR OLD.last_psn_sync_at IS DISTINCT FROM NEW.last_psn_sync_at OR OLD.last_xbox_sync_at IS DISTINCT FROM NEW.last_xbox_sync_at OR OLD.last_steam_sync_at IS DISTINCT FROM NEW.last_steam_sync_at)
 EXECUTE FUNCTION statusxp_private.publish_profile_sync_status();
INSERT INTO public.profile_sync_notifications SELECT id,psn_sync_status,xbox_sync_status,steam_sync_status,last_psn_sync_at,last_xbox_sync_at,last_steam_sync_at FROM public.profiles_private;
ALTER PUBLICATION supabase_realtime ADD TABLE public.profile_sync_notifications;
NOTIFY pgrst,'reload schema';
COMMIT;
