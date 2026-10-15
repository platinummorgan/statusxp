-- Keep the installed app's profile endpoint while masking credentials.
-- Only the service role can read raw credentials through the public endpoint.
-- Administrative database sessions can use the protected underlying table.
BEGIN;
SET LOCAL lock_timeout='5s';
CREATE SCHEMA IF NOT EXISTS statusxp_private;
REVOKE ALL ON SCHEMA statusxp_private FROM PUBLIC,anon,authenticated;

ALTER TABLE public.profiles RENAME TO profiles_private;
REVOKE ALL ON public.profiles_private FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON public.profiles_private TO service_role;
-- Defense in depth if a future migration accidentally restores client grants.
ALTER POLICY profiles_select_policy ON public.profiles_private
 TO authenticated USING ((SELECT auth.uid())=id);

CREATE VIEW public.profiles AS SELECT
 p.id,
 p.username,
 p.display_name,
 p.avatar_url,
 p.psn_online_id,
 p.xbox_gamertag,
 p.steam_id,
 p.created_at,
 p.updated_at,
 p.psn_account_id,
 CASE WHEN auth.role() = 'service_role' THEN p.psn_npsso_token ELSE NULL::text END AS psn_npsso_token,
 CASE WHEN auth.role() = 'service_role' THEN p.psn_access_token ELSE NULL::text END AS psn_access_token,
 CASE WHEN auth.role() = 'service_role' THEN p.psn_refresh_token ELSE NULL::text END AS psn_refresh_token,
 p.psn_token_expires_at,
 p.last_psn_sync_at,
 p.psn_sync_status,
 p.psn_sync_error,
 p.psn_sync_progress,
 p.subscription_tier,
 p.subscription_expires_at,
 p.psn_avatar_url,
 p.psn_is_plus,
 p.xbox_xuid,
 CASE WHEN auth.role() = 'service_role' THEN p.xbox_access_token ELSE NULL::text END AS xbox_access_token,
 CASE WHEN auth.role() = 'service_role' THEN p.xbox_refresh_token ELSE NULL::text END AS xbox_refresh_token,
 p.xbox_token_expires_at,
 p.xbox_sync_status,
 p.last_xbox_sync_at,
 p.xbox_sync_error,
 p.xbox_sync_progress,
 CASE WHEN auth.role() = 'service_role' THEN p.xbox_user_hash ELSE NULL::text END AS xbox_user_hash,
 p.steam_sync_status,
 p.steam_sync_progress,
 p.steam_sync_error,
 p.last_steam_sync_at,
 CASE WHEN auth.role() = 'service_role' THEN p.steam_api_key ELSE NULL::text END AS steam_api_key,
 p.preferred_display_platform,
 p.steam_display_name,
 p.xbox_avatar_url,
 p.steam_avatar_url,
 p.merged_into_user_id,
 p.merged_at,
 p.show_on_leaderboard,
 p.twitch_user_id,
 p.xbox_profile_gamerscore
 FROM public.profiles_private p;
GRANT SELECT ON public.profiles TO anon,authenticated,service_role;
GRANT UPDATE ON public.profiles TO authenticated,service_role;
GRANT INSERT,DELETE ON public.profiles TO service_role;

CREATE OR REPLACE FUNCTION statusxp_private.write_profile_view()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE
 trusted boolean := (auth.role() = 'service_role' OR (auth.role() IS NULL AND current_setting('role', true) IN ('none','postgres','supabase_admin','service_role')));
 actor uuid := auth.uid();
 patch jsonb; payload jsonb; assignments text; columns_sql text; values_sql text;
 allowed text[] := ARRAY['username','display_name','avatar_url','preferred_display_platform','show_on_leaderboard'];
 psn_disconnect boolean := false; xbox_disconnect boolean := false; steam_disconnect boolean := false;
BEGIN
 IF TG_OP='DELETE' THEN
  IF NOT trusted THEN RAISE EXCEPTION 'Profile deletion requires the account deletion service' USING ERRCODE='42501'; END IF;
  DELETE FROM public.profiles_private WHERE id=OLD.id;
  RETURN OLD;
 END IF;
 IF TG_OP='INSERT' THEN
  IF NOT trusted THEN RAISE EXCEPTION 'Profile creation requires the account service' USING ERRCODE='42501'; END IF;
  payload:=jsonb_strip_nulls(to_jsonb(NEW));
  SELECT string_agg(format('%I',key),',' ORDER BY key),string_agg(format('r.%I',key),',' ORDER BY key)
   INTO columns_sql,values_sql FROM jsonb_each(payload);
  EXECUTE format('INSERT INTO public.profiles_private (%s) SELECT %s FROM jsonb_populate_record(NULL::public.profiles_private,$1) r',columns_sql,values_sql) USING payload;
  RETURN NEW;
 END IF;
 IF NEW.id IS DISTINCT FROM OLD.id THEN RAISE EXCEPTION 'Profile owner cannot change' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_object_agg(n.key,n.value),'{}'::jsonb) INTO patch
  FROM jsonb_each(to_jsonb(NEW)) n WHERE n.value IS DISTINCT FROM to_jsonb(OLD)->n.key;
 IF NOT trusted THEN
  IF actor IS NULL OR actor<>OLD.id THEN RAISE EXCEPTION 'Only your own profile can be edited' USING ERRCODE='42501'; END IF;
  psn_disconnect := NEW.psn_account_id IS NULL AND NEW.psn_online_id IS NULL AND (OLD.psn_account_id IS NOT NULL OR OLD.psn_online_id IS NOT NULL);
  xbox_disconnect := NEW.xbox_xuid IS NULL AND NEW.xbox_gamertag IS NULL AND (OLD.xbox_xuid IS NOT NULL OR OLD.xbox_gamertag IS NOT NULL);
  steam_disconnect := NEW.steam_id IS NULL AND OLD.steam_id IS NOT NULL;
  IF psn_disconnect THEN
   allowed:=allowed||ARRAY['psn_account_id','psn_online_id','psn_npsso_token','psn_access_token','psn_refresh_token','psn_token_expires_at','psn_sync_status'];
   IF NEW.psn_npsso_token IS NOT NULL OR NEW.psn_access_token IS NOT NULL OR NEW.psn_refresh_token IS NOT NULL OR NEW.psn_token_expires_at IS NOT NULL OR NEW.psn_sync_status<>'never_synced'
   THEN RAISE EXCEPTION 'Invalid PlayStation disconnect' USING ERRCODE='42501'; END IF;
  END IF;
  IF xbox_disconnect THEN
   allowed:=allowed||ARRAY['xbox_xuid','xbox_gamertag','xbox_access_token','xbox_refresh_token','xbox_token_expires_at','xbox_sync_status'];
   IF NEW.xbox_access_token IS NOT NULL OR NEW.xbox_refresh_token IS NOT NULL OR NEW.xbox_token_expires_at IS NOT NULL OR NEW.xbox_sync_status<>'never_synced'
   THEN RAISE EXCEPTION 'Invalid Xbox disconnect' USING ERRCODE='42501'; END IF;
  END IF;
  IF steam_disconnect THEN
   allowed:=allowed||ARRAY['steam_id','steam_api_key','steam_sync_status'];
   IF NEW.steam_api_key IS NOT NULL OR NEW.steam_sync_status<>'never_synced' THEN RAISE EXCEPTION 'Invalid Steam disconnect' USING ERRCODE='42501'; END IF;
  ELSIF patch ? 'steam_id' OR patch ? 'steam_api_key' THEN
   -- Compatibility with the installed Steam setup form. The submitted key is
   -- write-only to clients and never becomes visible through this view.
   allowed:=allowed||ARRAY['steam_id','steam_api_key'];
   IF NEW.steam_id IS NULL OR NEW.steam_id !~ '^[0-9]{17}$' OR NEW.steam_api_key IS NULL OR NEW.steam_api_key !~ '^[a-fA-F0-9]{32}$'
   THEN RAISE EXCEPTION 'A valid Steam ID and API key are required' USING ERRCODE='22023'; END IF;
   PERFORM pg_advisory_xact_lock(hashtextextended('steam-link:'||NEW.steam_id,0));
   IF EXISTS(SELECT 1 FROM public.profiles_private WHERE steam_id=NEW.steam_id AND id<>actor)
   THEN RAISE EXCEPTION 'Steam account is already connected to another user' USING ERRCODE='23505'; END IF;
  END IF;
  IF EXISTS(SELECT 1 FROM jsonb_object_keys(patch) k WHERE NOT k=ANY(allowed))
  THEN RAISE EXCEPTION 'Server-managed profile fields cannot be edited' USING ERRCODE='42501'; END IF;
  IF psn_disconnect THEN patch:=patch||jsonb_build_object('psn_npsso_token',NULL,'psn_access_token',NULL,'psn_refresh_token',NULL,'psn_token_expires_at',NULL); END IF;
  IF xbox_disconnect THEN patch:=patch||jsonb_build_object('xbox_access_token',NULL,'xbox_refresh_token',NULL,'xbox_user_hash',NULL,'xbox_token_expires_at',NULL); END IF;
  IF steam_disconnect THEN patch:=patch||jsonb_build_object('steam_api_key',NULL,'steam_display_name',NULL,'steam_avatar_url',NULL); END IF;
 END IF;
 IF patch='{}'::jsonb THEN RETURN NEW; END IF;
 payload:=to_jsonb(NEW)||patch;
 SELECT string_agg(format('%I = r.%I',key,key),',' ORDER BY key) INTO assignments FROM jsonb_each(patch);
 EXECUTE format('UPDATE public.profiles_private p SET %s FROM jsonb_populate_record(NULL::public.profiles_private,$1) r WHERE p.id=$2',assignments) USING payload,OLD.id;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION statusxp_private.write_profile_view() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER write_profile_view INSTEAD OF INSERT OR UPDATE OR DELETE ON public.profiles
 FOR EACH ROW EXECUTE FUNCTION statusxp_private.write_profile_view();

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  INSERT INTO public.profiles_private (id, username, created_at, updated_at)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    now(),
    now()
  );
  RETURN new;
END;
$function$
;
NOTIFY pgrst, 'reload schema';
COMMIT;
