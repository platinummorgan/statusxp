BEGIN;
SET LOCAL lock_timeout='10s';
-- Limit the selected earned rows before evaluating artwork and notable-trophy detail.
CREATE FUNCTION statusxp_private.platinum_card_page(p_user uuid,p_offset integer,p_limit integer,p_platform bigint DEFAULT NULL,p_game text DEFAULT NULL,p_achievement text DEFAULT NULL,p_keys jsonb DEFAULT NULL)
RETURNS TABLE(platform_id bigint, platform_game_id text, platform_achievement_id text,
 game_name text, trophy_name text, cover_url text, icon_url text, earned_at timestamptz,
 rarity numeric, platinum_number bigint, player_name text, avatar_url text, notable jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH owned AS (
  SELECT u.*,row_number() OVER(ORDER BY u.earned_at,u.platform_id,u.platform_game_id,u.platform_achievement_id) ordinal
  FROM public.user_achievements u JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
  WHERE u.user_id=p_user AND u.platform_id IN(1,2,5,9) AND a.is_platinum=true
 ), selected AS (
  SELECT * FROM owned WHERE (p_platform IS NULL OR platform_id=p_platform)
   AND (p_game IS NULL OR platform_game_id=p_game)
   AND (p_achievement IS NULL OR platform_achievement_id=p_achievement)
   AND (p_keys IS NULL OR p_keys @> jsonb_build_array(jsonb_build_object('platform_id',platform_id,'platform_game_id',platform_game_id,'platform_achievement_id',platform_achievement_id)))
  ORDER BY ordinal DESC OFFSET p_offset LIMIT p_limit
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
 FROM selected o JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 JOIN public.games g USING(platform_id,platform_game_id) JOIN public.profiles_private p ON p.id=p_user;
$$;
REVOKE ALL ON FUNCTION statusxp_private.platinum_card_page(uuid,integer,integer,bigint,text,text,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.get_my_platinum_cards(p_offset integer DEFAULT 0,p_limit integer DEFAULT 40)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 IF p_offset IS NULL OR p_limit IS NULL OR p_offset<0 OR p_limit<1 OR p_limit>100 THEN RAISE EXCEPTION 'Invalid page'; END IF;
 RETURN coalesce((SELECT jsonb_agg(to_jsonb(f)) FROM (
  SELECT * FROM statusxp_private.platinum_card_page(auth.uid(),p_offset,p_limit) ORDER BY platinum_number DESC
 ) f),'[]'::jsonb);
END $$;

CREATE OR REPLACE FUNCTION public.get_my_platinum_card(p_platform bigint,p_game text,p_achievement text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Sign in required' USING ERRCODE='42501'; END IF;
 RETURN (SELECT to_jsonb(f) FROM statusxp_private.platinum_card_page(auth.uid(),0,1,p_platform,p_game,p_achievement) f);
END $$;
REVOKE ALL ON FUNCTION public.get_my_platinum_card(bigint,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_platinum_card(bigint,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.discover_my_platinum_celebration()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_user uuid:=auth.uid(); s statusxp_private.platinum_celebration_state%ROWTYPE;
 v_count integer; v_items jsonb; v_historical boolean; v_id uuid; v_keys jsonb;
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
 )
 SELECT count(*)::integer,
 coalesce(jsonb_agg(jsonb_build_object('platform_id',i.platform_id,'platform_game_id',i.platform_game_id,'platform_achievement_id',i.platform_achievement_id)),'[]'::jsonb),
 NOT s.initialized OR count(*)>10 OR coalesce(bool_or(u.earned_at<now()-interval '30 days'),false)
 INTO v_count,v_keys,v_historical FROM inserted i JOIN public.user_achievements u
 ON u.user_id=v_user AND u.platform_id=i.platform_id AND u.platform_game_id=i.platform_game_id AND u.platform_achievement_id=i.platform_achievement_id;
 SELECT coalesce(jsonb_agg(to_jsonb(f)),'[]'::jsonb) INTO v_items
 FROM statusxp_private.platinum_card_page(v_user,0,50,NULL,NULL,NULL,v_keys) f;
 -- An empty pre-sync account must still get a collection summary on its first import.
 IF v_count=0 THEN RETURN NULL; END IF;
 v_id:=gen_random_uuid();
 UPDATE statusxp_private.platinum_celebration_state SET initialized=true,pending_id=v_id,pending_count=v_count,
 pending_historical=v_historical,pending_items=v_items WHERE user_id=v_user;
 RETURN jsonb_build_object('id',v_id,'count',v_count,'historical',v_historical,'items',v_items);
END $$;

COMMIT;
