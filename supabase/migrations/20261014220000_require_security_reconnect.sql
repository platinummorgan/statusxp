BEGIN;
SET LOCAL lock_timeout='10s';
CREATE TABLE statusxp_private.security_reconnect_requirements(
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 platform text NOT NULL CHECK(platform IN('psn','xbox','steam')),
 account_id text NOT NULL,
 original_credential_hash text NOT NULL,
 enrolled_at timestamptz NOT NULL DEFAULT now(),
 activated_at timestamptz,
 user_reported_reset_at timestamptz,
 reconnected_at timestamptz,
 provider_revocation_verified_at timestamptz,
 PRIMARY KEY(user_id,platform)
);
ALTER TABLE statusxp_private.security_reconnect_requirements ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON statusxp_private.security_reconnect_requirements FROM PUBLIC,anon,authenticated,service_role;

-- Conservative current cohort. Do not clear tokens or activate the gate for
-- installed clients; each owner activates it on entering the updated app.
INSERT INTO statusxp_private.security_reconnect_requirements(user_id,platform,account_id,original_credential_hash)
SELECT p.id,v.platform,v.account_id,encode(extensions.digest(v.credential,'sha256'),'hex')
FROM public.profiles_private p JOIN auth.users a ON a.id=p.id
CROSS JOIN LATERAL (VALUES
 ('psn',p.psn_account_id,p.psn_npsso_token),
 ('xbox',p.xbox_xuid,p.xbox_refresh_token),
 ('steam',p.steam_id,lower(p.steam_api_key))
) v(platform,account_id,credential)
WHERE a.deleted_at IS NULL AND p.merged_into_user_id IS NULL
 AND coalesce(v.account_id,'')<>'' AND coalesce(v.credential,'')<>'';

CREATE FUNCTION public.activate_security_reconnect()
RETURNS TABLE(platform text,account_id text,reset_reported boolean,sync_active boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE owner uuid:=auth.uid();
BEGIN
 IF owner IS NULL THEN RAISE EXCEPTION 'Sign in required.' USING ERRCODE='42501'; END IF;
 UPDATE statusxp_private.security_reconnect_requirements r SET activated_at=coalesce(r.activated_at,now())
 WHERE r.user_id=owner AND r.reconnected_at IS NULL;
 RETURN QUERY SELECT r.platform,r.account_id,r.user_reported_reset_at IS NOT NULL,
  coalesce(CASE r.platform WHEN 'psn' THEN p.psn_sync_status WHEN 'xbox' THEN p.xbox_sync_status ELSE p.steam_sync_status END IN('syncing','cancelling'),false)
 FROM statusxp_private.security_reconnect_requirements r JOIN public.profiles_private p ON p.id=r.user_id
 WHERE r.user_id=owner AND r.reconnected_at IS NULL ORDER BY r.platform;
END $$;
CREATE FUNCTION public.report_security_provider_reset(p_platform text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required.' USING ERRCODE='42501'; END IF;
 UPDATE statusxp_private.security_reconnect_requirements SET user_reported_reset_at=coalesce(user_reported_reset_at,now())
 WHERE user_id=auth.uid() AND platform=p_platform AND activated_at IS NOT NULL AND reconnected_at IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'No pending reconnect for this account.' USING ERRCODE='55000'; END IF;
END $$;

CREATE FUNCTION public.complete_verified_security_reconnect(p_user_id uuid,p_platform text,p_verified_account_id text,p_verified_credential_hash text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r statusxp_private.security_reconnect_requirements; p public.profiles_private; current_id text; credential text;
BEGIN
 SELECT * INTO p FROM public.profiles_private WHERE id=p_user_id FOR UPDATE;
 SELECT * INTO r FROM statusxp_private.security_reconnect_requirements WHERE user_id=p_user_id AND platform=p_platform FOR UPDATE;
 IF NOT FOUND OR r.activated_at IS NULL OR r.reconnected_at IS NOT NULL THEN RETURN false; END IF;
 IF r.user_reported_reset_at IS NULL THEN RAISE EXCEPTION 'Complete the provider security steps before reconnecting.' USING ERRCODE='55000'; END IF;
 current_id:=CASE p_platform WHEN 'psn' THEN p.psn_account_id WHEN 'xbox' THEN p.xbox_xuid ELSE p.steam_id END;
 credential:=CASE p_platform WHEN 'psn' THEN p.psn_npsso_token WHEN 'xbox' THEN p.xbox_refresh_token ELSE lower(p.steam_api_key) END;
 IF current_id IS DISTINCT FROM r.account_id OR p_verified_account_id IS DISTINCT FROM r.account_id THEN
  RAISE EXCEPTION 'Reconnect the same gaming account to preserve your saved stats.' USING ERRCODE='55000'; END IF;
 IF p_verified_credential_hash IS NULL OR p_verified_credential_hash IS DISTINCT FROM encode(extensions.digest(credential,'sha256'),'hex') THEN
  RAISE EXCEPTION 'Your connection changed during verification. Try reconnecting again.' USING ERRCODE='55000'; END IF;
 IF coalesce(credential,'')='' OR p_verified_credential_hash=r.original_credential_hash THEN
  RAISE EXCEPTION 'Use a new sign-in session or replacement Steam key to reconnect.' USING ERRCODE='55000'; END IF;
 UPDATE statusxp_private.security_reconnect_requirements SET reconnected_at=now() WHERE user_id=p_user_id AND platform=p_platform;
 -- User confirmation and fresh provider-verified credentials are recorded
 -- separately from proof that every previously issued token was revoked.
 RETURN true;
END $$;
CREATE FUNCTION public.assert_security_reconnect_complete(p_user_id uuid,p_platform text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM statusxp_private.security_reconnect_requirements WHERE user_id=p_user_id AND platform=p_platform AND activated_at IS NOT NULL AND reconnected_at IS NULL) THEN
  RAISE EXCEPTION 'Reconnect this gaming account in the updated app before syncing.' USING ERRCODE='55000'; END IF;
END $$;
CREATE FUNCTION statusxp_private.guard_security_reconnect_identity()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r record; current_id text;
BEGIN
 FOR r IN SELECT platform,account_id FROM statusxp_private.security_reconnect_requirements WHERE user_id=OLD.id AND activated_at IS NOT NULL AND reconnected_at IS NULL LOOP
  current_id:=CASE r.platform WHEN 'psn' THEN NEW.psn_account_id WHEN 'xbox' THEN NEW.xbox_xuid ELSE NEW.steam_id END;
  IF current_id IS NOT NULL AND current_id IS DISTINCT FROM r.account_id THEN
   RAISE EXCEPTION 'Reconnect the same gaming account to preserve your saved stats.' USING ERRCODE='55000'; END IF;
 END LOOP;
 RETURN NEW;
END $$;
CREATE TRIGGER guard_security_reconnect_identity BEFORE UPDATE ON public.profiles_private
FOR EACH ROW EXECUTE FUNCTION statusxp_private.guard_security_reconnect_identity();
REVOKE ALL ON FUNCTION public.activate_security_reconnect() FROM PUBLIC,anon,service_role;
REVOKE ALL ON FUNCTION public.report_security_provider_reset(text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.activate_security_reconnect(),public.report_security_provider_reset(text) TO authenticated;
REVOKE ALL ON FUNCTION public.complete_verified_security_reconnect(uuid,text,text,text),public.assert_security_reconnect_complete(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.complete_verified_security_reconnect(uuid,text,text,text),public.assert_security_reconnect_complete(uuid,text) TO service_role;
REVOKE ALL ON FUNCTION statusxp_private.guard_security_reconnect_identity() FROM PUBLIC,anon,authenticated;

-- Add admission checks to the two already reviewed atomic start functions.
DO $$ DECLARE name text; definition text; signature regprocedure; BEGIN
 FOREACH name IN ARRAY ARRAY['public.begin_verified_xbox_sync(uuid,text)','public.begin_verified_platform_sync(uuid,text,text)'] LOOP
  signature:=name::regprocedure;
  definition:=pg_get_functiondef(signature);
  IF name LIKE '%xbox%' THEN
   definition:=replace(definition,'UPDATE public.xbox_sync_logs SET',
    'PERFORM public.assert_security_reconnect_complete(p_user_id,''xbox''); UPDATE public.xbox_sync_logs SET');
  ELSE
   definition:=replace(definition,'EXECUTE format(''UPDATE public.%I SET status=',
    'PERFORM public.assert_security_reconnect_complete(p_user_id,p_platform); EXECUTE format(''UPDATE public.%I SET status=');
  END IF;
  IF definition NOT LIKE '%PERFORM public.assert_security_reconnect_complete%' THEN RAISE EXCEPTION 'Start function did not match reviewed definition'; END IF;
  EXECUTE definition;
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
