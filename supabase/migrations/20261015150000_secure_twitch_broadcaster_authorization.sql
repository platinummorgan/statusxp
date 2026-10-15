BEGIN;
SET LOCAL lock_timeout='10s';
CREATE TABLE statusxp_private.twitch_broadcaster_oauth_states(
 state_hash text PRIMARY KEY CHECK(state_hash ~ '^[a-f0-9]{64}$'),
 expires_at timestamptz NOT NULL,
 claimed_at timestamptz,
 completed_at timestamptz
);
CREATE TABLE statusxp_private.twitch_broadcaster_credentials(
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 broadcaster_id text NOT NULL,
 client_id text NOT NULL,
 access_token text NOT NULL,
 refresh_token text NOT NULL,
 expires_at timestamptz NOT NULL,
 revision bigint NOT NULL DEFAULT 1,
 refresh_lease uuid,
 refresh_lease_until timestamptz,
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE statusxp_private.twitch_broadcaster_oauth_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE statusxp_private.twitch_broadcaster_credentials ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON statusxp_private.twitch_broadcaster_oauth_states,statusxp_private.twitch_broadcaster_credentials FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.begin_twitch_broadcaster_authorization(p_state_hash text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 DELETE FROM statusxp_private.twitch_broadcaster_oauth_states WHERE expires_at<now()-interval '1 day';
 INSERT INTO statusxp_private.twitch_broadcaster_oauth_states(state_hash,expires_at) VALUES(p_state_hash,now()+interval '30 minutes');
END $$;
CREATE FUNCTION public.claim_twitch_broadcaster_authorization(p_state_hash text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 UPDATE statusxp_private.twitch_broadcaster_oauth_states SET claimed_at=now()
 WHERE state_hash=p_state_hash AND claimed_at IS NULL AND expires_at>now();
 RETURN FOUND;
END $$;
CREATE FUNCTION public.save_verified_twitch_broadcaster_authorization(p_state_hash text,p_broadcaster_id text,p_client_id text,p_access_token text,p_refresh_token text,p_expires_at timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF p_broadcaster_id !~ '^[0-9]+$' OR coalesce(p_client_id,'')='' OR coalesce(p_access_token,'')='' OR coalesce(p_refresh_token,'')='' OR p_expires_at IS NULL OR p_expires_at<=now() OR p_broadcaster_id IS NULL THEN
  RAISE EXCEPTION 'Invalid verified Twitch authorization.' USING ERRCODE='22023'; END IF;
 UPDATE statusxp_private.twitch_broadcaster_oauth_states SET completed_at=now()
 WHERE state_hash=p_state_hash AND claimed_at IS NOT NULL AND completed_at IS NULL AND expires_at>now();
 IF NOT FOUND THEN RAISE EXCEPTION 'Authorization link expired or already used.' USING ERRCODE='55000'; END IF;
 INSERT INTO statusxp_private.twitch_broadcaster_credentials(singleton,broadcaster_id,client_id,access_token,refresh_token,expires_at)
 VALUES(true,p_broadcaster_id,p_client_id,p_access_token,p_refresh_token,p_expires_at)
 ON CONFLICT(singleton) DO UPDATE SET broadcaster_id=excluded.broadcaster_id,client_id=excluded.client_id,
  access_token=excluded.access_token,refresh_token=excluded.refresh_token,expires_at=excluded.expires_at,
  revision=twitch_broadcaster_credentials.revision+1,refresh_lease=NULL,refresh_lease_until=NULL,updated_at=now();
END $$;
CREATE FUNCTION public.get_twitch_broadcaster_credentials()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT to_jsonb(c)-'singleton' FROM statusxp_private.twitch_broadcaster_credentials c WHERE singleton
$$;
CREATE FUNCTION public.claim_twitch_broadcaster_refresh(p_revision bigint,p_lease uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 UPDATE statusxp_private.twitch_broadcaster_credentials SET refresh_lease=p_lease,refresh_lease_until=now()+interval '45 seconds'
 WHERE singleton AND revision=p_revision AND coalesce(refresh_lease_until,'-infinity'::timestamptz)<now();
 RETURN FOUND;
END $$;
CREATE FUNCTION public.save_twitch_broadcaster_refresh(p_revision bigint,p_lease uuid,p_access_token text,p_refresh_token text,p_expires_at timestamptz)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF coalesce(p_access_token,'')='' OR coalesce(p_refresh_token,'')='' OR p_expires_at IS NULL OR p_expires_at<=now() THEN
  RAISE EXCEPTION 'Invalid Twitch token refresh.' USING ERRCODE='22023'; END IF;
 UPDATE statusxp_private.twitch_broadcaster_credentials SET access_token=p_access_token,refresh_token=p_refresh_token,
  expires_at=p_expires_at,revision=revision+1,refresh_lease=NULL,refresh_lease_until=NULL,updated_at=now()
 WHERE singleton AND revision=p_revision AND refresh_lease=p_lease AND refresh_lease_until>now();
 RETURN FOUND;
END $$;
CREATE FUNCTION public.release_twitch_broadcaster_refresh(p_revision bigint,p_lease uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 UPDATE statusxp_private.twitch_broadcaster_credentials SET refresh_lease=NULL,refresh_lease_until=NULL
 WHERE singleton AND revision=p_revision AND refresh_lease=p_lease
$$;
DO $$ DECLARE f record; BEGIN
 FOR f IN SELECT p.oid::regprocedure signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN(
 'begin_twitch_broadcaster_authorization','claim_twitch_broadcaster_authorization','save_verified_twitch_broadcaster_authorization','get_twitch_broadcaster_credentials','claim_twitch_broadcaster_refresh','save_twitch_broadcaster_refresh','release_twitch_broadcaster_refresh') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated',f.signature);
  EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role',f.signature);
 END LOOP;
END $$;
NOTIFY pgrst,'reload schema';
COMMIT;
