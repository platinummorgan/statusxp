BEGIN;
SET LOCAL lock_timeout='10s';
CREATE OR REPLACE FUNCTION public.begin_verified_platform_sync(p_user_id uuid,p_platform text,p_expected_account_id text)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE p public.profiles_private; account_id text; state text; new_log bigint;
BEGIN
 IF p_platform NOT IN('psn','steam') OR p_platform IS NULL THEN RAISE EXCEPTION 'Invalid platform'; END IF;
 SELECT * INTO p FROM public.profiles_private WHERE id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found.' USING ERRCODE='P0002'; END IF;
 account_id:=CASE p_platform WHEN 'psn' THEN p.psn_account_id ELSE p.steam_id END;
 state:=CASE p_platform WHEN 'psn' THEN p.psn_sync_status ELSE p.steam_sync_status END;
 IF account_id IS NULL OR account_id IS DISTINCT FROM p_expected_account_id
 OR (p_platform='psn' AND coalesce(p.psn_refresh_token,'')='') THEN
  RAISE EXCEPTION 'Connection changed or needs reconnection.' USING ERRCODE='55000'; END IF;
 IF state IN('syncing','cancelling') THEN RAISE EXCEPTION 'Sync already in progress.' USING ERRCODE='55000'; END IF;
 EXECUTE format('UPDATE public.%I SET status=''failed'',completed_at=now(),error_message=''Superseded by a new sync.'' WHERE user_id=$1 AND status IN(''pending'',''syncing'')',p_platform||'_sync_logs') USING p_user_id;
 EXECUTE format('INSERT INTO public.%I(user_id,sync_type,status,started_at) VALUES($1,''full'',''pending'',now()) RETURNING id',p_platform||'_sync_logs') INTO new_log USING p_user_id;
 EXECUTE format('UPDATE public.profiles_private SET %I=''syncing'',%I=0,%I=NULL WHERE id=$1',p_platform||'_sync_status',p_platform||'_sync_progress',p_platform||'_sync_error') USING p_user_id;
 RETURN new_log;
END $$;
REVOKE ALL ON FUNCTION public.begin_verified_platform_sync(uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.begin_verified_platform_sync(uuid,text,text) TO service_role;

CREATE OR REPLACE FUNCTION statusxp_private.guard_platform_connection_during_sync()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
 IF OLD.psn_sync_status IN('syncing','cancelling') AND
 (OLD.psn_account_id IS DISTINCT FROM NEW.psn_account_id OR OLD.psn_npsso_token IS DISTINCT FROM NEW.psn_npsso_token) THEN
  RAISE EXCEPTION 'Stop the PlayStation sync before reconnecting or disconnecting.' USING ERRCODE='55000'; END IF;
 IF OLD.steam_sync_status IN('syncing','cancelling') AND
 (OLD.steam_id IS DISTINCT FROM NEW.steam_id OR OLD.steam_api_key IS DISTINCT FROM NEW.steam_api_key) THEN
  RAISE EXCEPTION 'Stop the Steam sync before changing its connection.' USING ERRCODE='55000'; END IF;
 IF NEW.psn_account_id IS NOT NULL AND OLD.psn_account_id IS DISTINCT FROM NEW.psn_account_id THEN
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('psn-account:'||NEW.psn_account_id,0));
  IF EXISTS(SELECT 1 FROM public.profiles_private WHERE id<>OLD.id AND psn_account_id=NEW.psn_account_id) THEN
   RAISE EXCEPTION 'This PlayStation account is already connected to another app account.' USING ERRCODE='23505'; END IF;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION statusxp_private.guard_platform_connection_during_sync() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_platform_connection_during_sync BEFORE UPDATE ON public.profiles_private
FOR EACH ROW EXECUTE FUNCTION statusxp_private.guard_platform_connection_during_sync();
NOTIFY pgrst,'reload schema';
COMMIT;
