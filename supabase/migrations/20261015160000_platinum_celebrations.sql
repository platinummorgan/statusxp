BEGIN;
SET LOCAL lock_timeout='10s';

-- Read only verified PSN unlocks. Windowing happens after the owner filter,
-- and deterministic tie breakers keep platinum numbers stable across pages.
CREATE FUNCTION statusxp_private.platinum_card_facts(p_user uuid)
RETURNS TABLE(platform_id bigint, platform_game_id text, platform_achievement_id text,
 game_name text, trophy_name text, cover_url text, icon_url text, earned_at timestamptz,
 rarity numeric, platinum_number bigint, player_name text, avatar_url text, notable jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH owned AS (
  SELECT u.*,row_number() OVER(ORDER BY u.earned_at,u.platform_id,u.platform_game_id,u.platform_achievement_id) ordinal
  FROM public.user_achievements u JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
  WHERE u.user_id=p_user AND u.platform_id IN(1,2,5,9) AND a.is_platinum=true
 )
 SELECT o.platform_id,o.platform_game_id,o.platform_achievement_id,g.name,a.name,
 g.cover_url,coalesce(a.proxied_icon_url,a.icon_url),o.earned_at,
 CASE WHEN a.rarity_global BETWEEN 0 AND 100 THEN a.rarity_global::numeric END,
 o.ordinal,coalesce(p.display_name,p.username,'Player'),coalesce(p.avatar_url,p.psn_avatar_url),
 coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM (
  SELECT b.name,coalesce(b.proxied_icon_url,b.icon_url) icon_url,b.rarity_global rarity
  FROM public.user_achievements u JOIN public.achievements b USING(platform_id,platform_game_id,platform_achievement_id)
  WHERE u.user_id=p_user AND u.platform_id=o.platform_id AND u.platform_game_id=o.platform_game_id
   AND b.is_platinum IS NOT TRUE AND b.rarity_global BETWEEN 0 AND 100
  ORDER BY b.rarity_global,b.platform_achievement_id LIMIT 3
 ) t),'[]'::jsonb)
 FROM owned o JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 JOIN public.games g USING(platform_id,platform_game_id) JOIN public.profiles_private p ON p.id=p_user;
$$;
REVOKE ALL ON FUNCTION statusxp_private.platinum_card_facts(uuid) FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.get_my_platinum_cards(p_offset integer DEFAULT 0,p_limit integer DEFAULT 40)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF p_offset IS NULL OR p_limit IS NULL OR p_offset<0 OR p_limit<1 OR p_limit>100 THEN RAISE EXCEPTION 'Invalid page'; END IF;
 RETURN coalesce((SELECT jsonb_agg(to_jsonb(f)) FROM (
  SELECT * FROM statusxp_private.platinum_card_facts(auth.uid()) ORDER BY platinum_number DESC OFFSET p_offset LIMIT p_limit
 ) f),'[]'::jsonb);
END $$;

CREATE FUNCTION public.get_my_platinum_card(p_platform bigint,p_game text,p_achievement text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 RETURN (SELECT to_jsonb(f) FROM statusxp_private.platinum_card_facts(auth.uid()) f
 WHERE platform_id=p_platform AND platform_game_id=p_game AND platform_achievement_id=p_achievement);
END $$;
REVOKE ALL ON FUNCTION public.get_my_platinum_card(bigint,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_platinum_card(bigint,text,text) TO authenticated;

CREATE TABLE statusxp_private.platinum_celebration_state(
 user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 initialized boolean NOT NULL DEFAULT false,
 pending_id uuid, pending_count integer, pending_historical boolean,
 pending_items jsonb, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE statusxp_private.platinum_celebration_seen(
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 platform_id bigint NOT NULL, platform_game_id text NOT NULL, platform_achievement_id text NOT NULL,
 PRIMARY KEY(user_id,platform_id,platform_game_id,platform_achievement_id)
);
ALTER TABLE statusxp_private.platinum_celebration_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE statusxp_private.platinum_celebration_seen ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON statusxp_private.platinum_celebration_state,statusxp_private.platinum_celebration_seen FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION public.discover_my_platinum_celebration()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid(); s statusxp_private.platinum_celebration_state%ROWTYPE;
 v_count integer; v_items jsonb; v_historical boolean; v_id uuid;
BEGIN
 IF v_user IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 INSERT INTO statusxp_private.platinum_celebration_state(user_id) VALUES(v_user) ON CONFLICT DO NOTHING;
 SELECT * INTO s FROM statusxp_private.platinum_celebration_state WHERE user_id=v_user FOR UPDATE;
 IF s.pending_id IS NOT NULL THEN
  RETURN jsonb_build_object('id',s.pending_id,'count',s.pending_count,'historical',s.pending_historical,'items',s.pending_items);
 END IF;
 -- Do not consume partial imports while PSN is still writing achievement rows.
 IF EXISTS(SELECT 1 FROM public.profiles_private p WHERE p.id=v_user AND p.psn_sync_status IN('syncing','pending','cancelling')) THEN RETURN NULL; END IF;
 WITH inserted AS (
  INSERT INTO statusxp_private.platinum_celebration_seen
  SELECT v_user,u.platform_id,u.platform_game_id,u.platform_achievement_id
  FROM public.user_achievements u JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
  WHERE u.user_id=v_user AND u.platform_id IN(1,2,5,9) AND a.is_platinum=true
  ON CONFLICT DO NOTHING RETURNING platform_id,platform_game_id,platform_achievement_id
 ), fresh AS MATERIALIZED (
  SELECT f.* FROM statusxp_private.platinum_card_facts(v_user) f JOIN inserted i USING(platform_id,platform_game_id,platform_achievement_id)
 )
 SELECT count(*)::integer,
 coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM(SELECT * FROM fresh ORDER BY platinum_number DESC LIMIT 50)t),'[]'::jsonb),
 NOT s.initialized OR count(*)>10 OR coalesce(bool_or(earned_at<now()-interval '30 days'),false)
 INTO v_count,v_items,v_historical FROM fresh;
 -- An empty pre-sync account must still get a collection summary on its first import.
 IF v_count=0 THEN RETURN NULL; END IF;
 v_id:=gen_random_uuid();
 UPDATE statusxp_private.platinum_celebration_state SET initialized=true,pending_id=v_id,pending_count=v_count,
 pending_historical=v_historical,pending_items=v_items WHERE user_id=v_user;
 RETURN jsonb_build_object('id',v_id,'count',v_count,'historical',v_historical,'items',v_items);
END $$;

CREATE FUNCTION public.acknowledge_my_platinum_celebration(p_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 UPDATE statusxp_private.platinum_celebration_state SET pending_id=NULL,pending_items=NULL,pending_count=NULL,pending_historical=NULL
 WHERE user_id=auth.uid() AND pending_id=p_id;
 RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION public.get_my_platinum_cards(integer,integer),public.discover_my_platinum_celebration(),public.acknowledge_my_platinum_celebration(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_platinum_cards(integer,integer),public.discover_my_platinum_celebration(),public.acknowledge_my_platinum_celebration(uuid) TO authenticated;

-- Dedicated image allowance; guide credits cannot bypass the Premium wall.
-- Initial rollout allowance: 3 images per UTC calendar month; global cap 100/day.
CREATE TABLE statusxp_private.platinum_art_requests(
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, request_id uuid NOT NULL,
 input_hash text NOT NULL, state text NOT NULL CHECK(state IN('pending','succeeded','failed','abandoned')),
 object_path text, created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL DEFAULT now()+interval '10 minutes',
 PRIMARY KEY(user_id,request_id)
);
CREATE INDEX platinum_art_created_idx ON statusxp_private.platinum_art_requests(created_at);
ALTER TABLE statusxp_private.platinum_art_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON statusxp_private.platinum_art_requests FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION public.reserve_platinum_art(p_user uuid,p_request uuid,p_hash text,p_platform bigint,p_game text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE r statusxp_private.platinum_art_requests%ROWTYPE; v_game text;
BEGIN
 IF p_hash !~ '^[a-f0-9]{64}$' OR p_request IS NULL OR p_user IS NULL THEN RAISE EXCEPTION 'Invalid request'; END IF;
 PERFORM pg_advisory_xact_lock(hashtext('statusxp_platinum_art'));
 IF NOT coalesce((public.effective_premium_entitlement(p_user)->>'is_premium')::boolean,false) THEN RETURN jsonb_build_object('state','premium_required'); END IF;
 SELECT g.name INTO v_game FROM public.user_achievements u JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 JOIN public.games g USING(platform_id,platform_game_id)
 WHERE u.user_id=p_user AND u.platform_id=p_platform AND u.platform_game_id=p_game AND a.is_platinum AND u.platform_id IN(1,2,5,9) LIMIT 1;
 IF v_game IS NULL THEN RETURN jsonb_build_object('state','not_owned'); END IF;
 UPDATE statusxp_private.platinum_art_requests SET state='abandoned' WHERE state='pending' AND expires_at<=now();
 SELECT * INTO r FROM statusxp_private.platinum_art_requests WHERE user_id=p_user AND request_id=p_request;
 IF FOUND THEN
  IF r.input_hash<>p_hash THEN RETURN jsonb_build_object('state','conflict'); END IF;
  RETURN jsonb_build_object('state',r.state,'object_path',r.object_path);
 END IF;
 IF EXISTS(SELECT 1 FROM statusxp_private.platinum_art_requests WHERE user_id=p_user AND state='pending') THEN RETURN jsonb_build_object('state','busy'); END IF;
 IF (SELECT count(*) FROM statusxp_private.platinum_art_requests WHERE user_id=p_user AND state<>'failed' AND created_at>=date_trunc('month',now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC')>=3
 OR (SELECT count(*) FROM statusxp_private.platinum_art_requests WHERE user_id=p_user AND created_at>=(now() AT TIME ZONE 'UTC')::date AT TIME ZONE 'UTC')>=10
 OR (SELECT count(*) FROM statusxp_private.platinum_art_requests WHERE created_at>=(now() AT TIME ZONE 'UTC')::date AT TIME ZONE 'UTC')>=100 THEN RETURN jsonb_build_object('state','limit_reached'); END IF;
 INSERT INTO statusxp_private.platinum_art_requests(user_id,request_id,input_hash,state) VALUES(p_user,p_request,p_hash,'pending');
 RETURN jsonb_build_object('state','reserved','game_name',v_game);
END $$;
CREATE FUNCTION public.finish_platinum_art(p_user uuid,p_request uuid,p_path text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF p_path IS NOT NULL AND p_path<>p_user::text||'/'||p_request::text||'.png' THEN RAISE EXCEPTION 'Invalid object path'; END IF;
 UPDATE statusxp_private.platinum_art_requests SET state=CASE WHEN p_path IS NULL THEN 'failed' ELSE 'succeeded' END,object_path=p_path
 WHERE user_id=p_user AND request_id=p_request AND state='pending' AND expires_at>now();
 RETURN FOUND;
END $$;
REVOKE ALL ON FUNCTION public.reserve_platinum_art(uuid,uuid,text,bigint,text),public.finish_platinum_art(uuid,uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_platinum_art(uuid,uuid,text,bigint,text),public.finish_platinum_art(uuid,uuid,text) TO service_role;
INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES('platinum-art','platinum-art',false,15728640,ARRAY['image/png']) ON CONFLICT(id) DO NOTHING;
CREATE POLICY platinum_art_owner_read ON storage.objects FOR SELECT TO authenticated
USING(bucket_id='platinum-art' AND (storage.foldername(name))[1]=auth.uid()::text);
COMMIT;
