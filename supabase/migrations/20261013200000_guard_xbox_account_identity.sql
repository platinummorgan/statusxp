BEGIN;
SET LOCAL lock_timeout='5s';
CREATE TABLE statusxp_private.xbox_account_bindings (
 user_id uuid PRIMARY KEY REFERENCES public.profiles_private(id) ON DELETE CASCADE,
 xuid text NOT NULL, observed_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE statusxp_private.xbox_binding_events (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 user_id uuid NOT NULL REFERENCES public.profiles_private(id) ON DELETE CASCADE,
 old_xuid text,new_xuid text,event text NOT NULL,observed_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON statusxp_private.xbox_account_bindings,statusxp_private.xbox_binding_events FROM PUBLIC,anon,authenticated;
INSERT INTO statusxp_private.xbox_account_bindings(user_id,xuid) SELECT id,xbox_xuid FROM public.profiles_private WHERE xbox_xuid IS NOT NULL;
-- This records the identity observed today, not the origin of historical stats.
INSERT INTO statusxp_private.xbox_binding_events(user_id,new_xuid,event) SELECT id,xbox_xuid,'baseline_observed' FROM public.profiles_private WHERE xbox_xuid IS NOT NULL;
CREATE OR REPLACE FUNCTION statusxp_private.guard_xbox_identity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE retained text; has_history boolean;
BEGIN
 IF OLD.xbox_sync_status IN('syncing','cancelling') THEN
  RAISE EXCEPTION 'Stop the Xbox sync before changing or disconnecting the Xbox account.' USING ERRCODE='55000';
 END IF;
 SELECT xuid INTO retained FROM statusxp_private.xbox_account_bindings WHERE user_id=OLD.id;
 retained:=coalesce(retained,OLD.xbox_xuid);
 SELECT EXISTS(SELECT 1 FROM public.user_progress WHERE user_id=OLD.id AND platform_id IN(10,11,12))
 OR EXISTS(SELECT 1 FROM public.user_achievements WHERE user_id=OLD.id AND platform_id IN(10,11,12))
 OR EXISTS(SELECT 1 FROM public.user_undated_achievements WHERE user_id=OLD.id) INTO has_history;
 IF NEW.xbox_xuid IS NOT NULL THEN
  PERFORM pg_advisory_xact_lock(hashtextextended('xbox-link:'||NEW.xbox_xuid,0));
  IF has_history AND retained IS NULL THEN
   RAISE EXCEPTION 'Existing Xbox stats have no saved account identity. Contact support to verify the account before reconnecting.' USING ERRCODE='55000';
  END IF;
  IF has_history AND retained IS DISTINCT FROM NEW.xbox_xuid THEN
   RAISE EXCEPTION 'Changing Xbox accounts would mix existing stats. Reconnect the previously linked Xbox account; contact support to change accounts.' USING ERRCODE='55000';
  END IF;
  IF EXISTS(SELECT 1 FROM public.profiles_private WHERE id<>OLD.id AND xbox_xuid=NEW.xbox_xuid)
   OR EXISTS(SELECT 1 FROM statusxp_private.xbox_account_bindings b JOIN public.profiles_private p ON p.id=b.user_id
    WHERE b.user_id<>OLD.id AND b.xuid=NEW.xbox_xuid AND p.merged_into_user_id IS NULL
     AND EXISTS(SELECT 1 FROM public.user_progress up WHERE up.user_id=b.user_id AND up.platform_id IN(10,11,12))) THEN
   RAISE EXCEPTION 'This Xbox account is already associated with another app account.' USING ERRCODE='23505';
  END IF;
  INSERT INTO statusxp_private.xbox_account_bindings(user_id,xuid) VALUES(OLD.id,NEW.xbox_xuid)
   ON CONFLICT(user_id) DO UPDATE SET xuid=excluded.xuid,observed_at=now();
 ELSIF retained IS NOT NULL THEN
  INSERT INTO statusxp_private.xbox_account_bindings(user_id,xuid) VALUES(OLD.id,retained) ON CONFLICT DO NOTHING;
 END IF;
 INSERT INTO statusxp_private.xbox_binding_events(user_id,old_xuid,new_xuid,event)
 VALUES(OLD.id,OLD.xbox_xuid,NEW.xbox_xuid,CASE WHEN NEW.xbox_xuid IS NULL THEN 'disconnected' WHEN OLD.xbox_xuid IS NULL THEN 'linked' ELSE 'identity_changed' END);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION statusxp_private.guard_xbox_identity() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_xbox_identity BEFORE UPDATE OF xbox_xuid ON public.profiles_private
FOR EACH ROW WHEN(OLD.xbox_xuid IS DISTINCT FROM NEW.xbox_xuid) EXECUTE FUNCTION statusxp_private.guard_xbox_identity();
CREATE OR REPLACE FUNCTION public.link_verified_xbox_account(
 p_user_id uuid,p_xuid text,p_gamertag text,p_user_hash text,p_access_token text,
 p_refresh_token text,p_expires_at timestamptz,p_gamerscore bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles_private; refresh_value text;
BEGIN
 IF p_xuid IS NULL OR p_xuid !~ '^[0-9]{1,20}$' OR coalesce(p_access_token,'')='' OR coalesce(p_user_hash,'')='' OR coalesce(p_gamertag,'')='' OR p_expires_at IS NULL OR p_expires_at<=now() OR p_gamerscore IS NULL OR p_gamerscore<0 THEN
  RAISE EXCEPTION 'Invalid verified Xbox connection.' USING ERRCODE='22023';
 END IF;
 SELECT * INTO p FROM public.profiles_private WHERE id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found.' USING ERRCODE='P0002'; END IF;
 IF p.xbox_sync_status IN('syncing','cancelling') THEN RAISE EXCEPTION 'Stop the Xbox sync before reconnecting.' USING ERRCODE='55000'; END IF;
 refresh_value:=nullif(p_refresh_token,'');
 IF refresh_value IS NULL AND p.xbox_xuid=p_xuid THEN refresh_value:=nullif(p.xbox_refresh_token,''); END IF;
 IF refresh_value IS NULL THEN RAISE EXCEPTION 'Reconnect through Microsoft sign-in to obtain offline access.' USING ERRCODE='22023'; END IF;
 UPDATE public.profiles_private SET xbox_xuid=p_xuid,xbox_gamertag=p_gamertag,xbox_user_hash=p_user_hash,
  xbox_access_token=p_access_token,xbox_refresh_token=refresh_value,xbox_token_expires_at=p_expires_at,
  xbox_profile_gamerscore=p_gamerscore,xbox_sync_status='never_synced',xbox_sync_progress=0,xbox_sync_error=NULL,
  xbox_avatar_url=CASE WHEN xbox_xuid IS DISTINCT FROM p_xuid THEN NULL ELSE xbox_avatar_url END,
  last_xbox_sync_at=CASE WHEN xbox_xuid IS DISTINCT FROM p_xuid THEN NULL ELSE last_xbox_sync_at END
 WHERE id=p_user_id;
END $$;
REVOKE ALL ON FUNCTION public.link_verified_xbox_account(uuid,text,text,text,text,text,timestamptz,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.link_verified_xbox_account(uuid,text,text,text,text,text,timestamptz,bigint) TO service_role;
CREATE OR REPLACE FUNCTION public.begin_verified_xbox_sync(p_user_id uuid,p_expected_xuid text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles_private; new_log bigint;
BEGIN
 SELECT * INTO p FROM public.profiles_private WHERE id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found.' USING ERRCODE='P0002'; END IF;
 IF p.xbox_xuid IS NULL OR p.xbox_xuid IS DISTINCT FROM p_expected_xuid OR coalesce(p.xbox_refresh_token,'')='' THEN
  RAISE EXCEPTION 'Xbox connection changed or needs reconnection.' USING ERRCODE='55000'; END IF;
 IF p.xbox_sync_status IN('syncing','cancelling') THEN RAISE EXCEPTION 'Xbox sync already in progress.' USING ERRCODE='55000'; END IF;
 UPDATE public.xbox_sync_logs SET status='failed',completed_at=now(),error_message='Superseded by a new Xbox sync.' WHERE user_id=p_user_id AND status IN('pending','syncing');
 INSERT INTO public.xbox_sync_logs(user_id,sync_type,status,started_at) VALUES(p_user_id,'full','pending',now()) RETURNING id INTO new_log;
 UPDATE public.profiles_private SET xbox_sync_status='syncing',xbox_sync_progress=0,xbox_sync_error=NULL WHERE id=p_user_id;
 RETURN new_log;
END $$;
REVOKE ALL ON FUNCTION public.begin_verified_xbox_sync(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.begin_verified_xbox_sync(uuid,text) TO service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
