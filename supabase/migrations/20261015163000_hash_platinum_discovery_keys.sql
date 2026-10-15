BEGIN;
-- Build the discovered-key set once rather than scan a JSON array for every trophy.
CREATE OR REPLACE FUNCTION statusxp_private.platinum_card_page(p_user uuid,p_offset integer,p_limit integer,p_platform bigint DEFAULT NULL,p_game text DEFAULT NULL,p_achievement text DEFAULT NULL,p_keys jsonb DEFAULT NULL)
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
   AND (p_keys IS NULL OR (platform_id,platform_game_id,platform_achievement_id) IN (SELECT k.platform_id,k.platform_game_id,k.platform_achievement_id FROM jsonb_to_recordset(p_keys) AS k(platform_id bigint,platform_game_id text,platform_achievement_id text)))
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

COMMIT;
