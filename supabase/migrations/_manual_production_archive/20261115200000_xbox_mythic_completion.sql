BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '120s';

-- These are completion records, never ordinary achievement rows.
CREATE TABLE public.xbox_mythic_catalog (
  platform_id bigint NOT NULL CHECK (platform_id IN (10,11,12)),
  platform_game_id text NOT NULL,
  required_achievement_ids jsonb,
  membership_revision text,
  rarity_source text NOT NULL DEFAULT 'estimated_minimum_base_game',
  estimated_rarity numeric CHECK (estimated_rarity BETWEEN 0 AND 100),
  base_status_xp numeric(6,2) GENERATED ALWAYS AS
    (CASE WHEN estimated_rarity IS NULL THEN 0.5
      ELSE round(0.5 + 57.5 * power(1 - estimated_rarity / 100.0, 3), 2) END) STORED,
  verified_at timestamptz,
  PRIMARY KEY (platform_id,platform_game_id),
  FOREIGN KEY (platform_id,platform_game_id) REFERENCES public.games ON DELETE CASCADE,
  CHECK (required_achievement_ids IS NULL OR
    (jsonb_typeof(required_achievement_ids) = 'array' AND jsonb_array_length(required_achievement_ids) > 0))
);
CREATE TABLE public.user_xbox_mythics (
  user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  platform_id bigint NOT NULL,
  platform_game_id text NOT NULL,
  source_xuid text NOT NULL,
  earned_at timestamptz,
  confirmed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id,platform_game_id),
  FOREIGN KEY (platform_id,platform_game_id) REFERENCES public.xbox_mythic_catalog ON DELETE CASCADE,
  CHECK (earned_at IS NULL OR earned_at > '1970-01-01'::timestamptz)
);
CREATE INDEX user_xbox_mythics_catalog_idx ON public.user_xbox_mythics(platform_id,platform_game_id);
CREATE INDEX user_xbox_mythics_earned_idx ON public.user_xbox_mythics(earned_at) WHERE earned_at IS NOT NULL;
CREATE TABLE public.xbox_mythic_sync_state (
  user_id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,
  source_xuid text NOT NULL,
  synced_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.xbox_mythic_leaderboard_history (
  user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  rank integer NOT NULL,
  mythic_count bigint NOT NULL,
  PRIMARY KEY (user_id,snapshot_at)
);
ALTER TABLE public.xbox_mythic_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_xbox_mythics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xbox_mythic_sync_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.xbox_mythic_leaderboard_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY mythic_catalog_read ON public.xbox_mythic_catalog FOR SELECT USING (true);
REVOKE ALL ON public.xbox_mythic_catalog FROM anon,authenticated;
GRANT SELECT ON public.xbox_mythic_catalog TO anon,authenticated;
REVOKE ALL ON public.user_xbox_mythics,public.xbox_mythic_sync_state,
  public.xbox_mythic_leaderboard_history FROM anon,authenticated;
GRANT ALL ON public.xbox_mythic_catalog,public.user_xbox_mythics,
  public.xbox_mythic_sync_state,public.xbox_mythic_leaderboard_history TO service_role;

-- Public projection hides provider identities and respects profile visibility.
CREATE VIEW public.xbox_mythic_awards WITH (security_barrier=true) AS
SELECT m.user_id,m.platform_id,m.platform_game_id,m.earned_at,
  c.estimated_rarity,c.rarity_source,c.base_status_xp,c.membership_revision
FROM public.user_xbox_mythics m
JOIN public.xbox_mythic_catalog c USING(platform_id,platform_game_id)
JOIN public.profiles_private p ON p.id=m.user_id AND p.xbox_xuid::text=m.source_xuid
WHERE p.merged_into_user_id IS NULL
  AND (p.show_on_leaderboard OR p.id=auth.uid()
    OR auth.role()='service_role' OR current_user='postgres');
GRANT SELECT ON public.xbox_mythic_awards TO anon,authenticated,service_role;

CREATE FUNCTION public.assert_xbox_mythic_sync(p_user_id uuid,p_xuid text,p_sync_log_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles_private p
    WHERE p.id=p_user_id AND p.xbox_xuid::text=p_xuid AND p.merged_into_user_id IS NULL)
    OR NOT EXISTS (SELECT 1 FROM public.xbox_sync_logs l
      WHERE l.id=p_sync_log_id AND l.user_id=p_user_id AND l.status IN ('pending','syncing')) THEN
    RAISE EXCEPTION 'Xbox account or sync session changed';
  END IF;
END;
$$;

CREATE FUNCTION public.record_xbox_mythic(p_user_id uuid,p_xuid text,p_sync_log_id bigint,
  p_platform_id bigint,p_platform_game_id text,p_is_mythic boolean,p_details jsonb DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_ids jsonb; v_revision text; v_rarity numeric; v_time timestamptz;
BEGIN
  PERFORM public.assert_xbox_mythic_sync(p_user_id,p_xuid,p_sync_log_id);
  IF p_platform_id NOT IN (10,11,12) OR p_is_mythic IS NULL THEN
    RAISE EXCEPTION 'Invalid Mythic platform or native confirmation';
  END IF;
  IF p_details IS NOT NULL AND p_details <> 'null'::jsonb THEN
    v_ids:=p_details->'required_ids'; v_revision:=p_details->>'membership_revision';
    v_rarity:=(p_details->>'estimated_rarity')::numeric;
    v_time:=(p_details->>'completed_at')::timestamptz;
    IF p_details->>'source' IS DISTINCT FROM 'xbox_live_contract_6'
      OR jsonb_typeof(v_ids) IS DISTINCT FROM 'array'
      OR jsonb_array_length(v_ids)=0 OR v_revision IS NULL
      OR EXISTS (SELECT 1 FROM jsonb_array_elements_text(v_ids) id
        WHERE NOT EXISTS (SELECT 1 FROM public.achievements a
          WHERE a.platform_id=p_platform_id AND a.platform_game_id=p_platform_game_id
            AND a.platform_achievement_id=id)) THEN
      RAISE EXCEPTION 'Incomplete Xbox base-game membership';
    END IF;
    IF v_time <= '1970-01-01'::timestamptz OR v_time > now() THEN v_time:=NULL; END IF;
  END IF;
  INSERT INTO public.xbox_mythic_catalog(platform_id,platform_game_id)
    VALUES(p_platform_id,p_platform_game_id) ON CONFLICT DO NOTHING;
  IF v_ids IS NOT NULL THEN
    UPDATE public.xbox_mythic_catalog SET required_achievement_ids=v_ids,
      membership_revision=v_revision,
      -- Preserve a verified estimate when a later response loses rarity fields.
      estimated_rarity=CASE WHEN v_rarity IS NOT NULL THEN v_rarity
        WHEN membership_revision=v_revision THEN estimated_rarity ELSE NULL END,
      verified_at=now()
    WHERE platform_id=p_platform_id AND platform_game_id=p_platform_game_id;
  END IF;
  IF p_is_mythic THEN
    INSERT INTO public.user_xbox_mythics(user_id,platform_id,platform_game_id,source_xuid,earned_at)
    VALUES(p_user_id,p_platform_id,p_platform_game_id,p_xuid,v_time)
    ON CONFLICT(user_id,platform_game_id) DO UPDATE SET
      platform_id=EXCLUDED.platform_id,source_xuid=EXCLUDED.source_xuid,
      earned_at=CASE WHEN user_xbox_mythics.source_xuid=EXCLUDED.source_xuid
        THEN COALESCE(user_xbox_mythics.earned_at,EXCLUDED.earned_at) ELSE EXCLUDED.earned_at END,
      confirmed_at=now();
  END IF;
  -- A false or missing follow-up must not revoke a confirmed native award.
END;
$$;
CREATE FUNCTION public.mark_xbox_mythics_synced(p_user_id uuid,p_xuid text,p_sync_log_id bigint)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
  PERFORM public.assert_xbox_mythic_sync(p_user_id,p_xuid,p_sync_log_id);
  INSERT INTO public.xbox_mythic_sync_state(user_id,source_xuid) VALUES(p_user_id,p_xuid)
    ON CONFLICT(user_id) DO UPDATE SET source_xuid=EXCLUDED.source_xuid,synced_at=now();
END;
$$;
REVOKE ALL ON FUNCTION public.assert_xbox_mythic_sync(uuid,text,bigint),
  public.record_xbox_mythic(uuid,text,bigint,bigint,text,boolean,jsonb),
  public.mark_xbox_mythics_synced(uuid,text,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.record_xbox_mythic(uuid,text,bigint,bigint,text,boolean,jsonb),
  public.mark_xbox_mythics_synced(uuid,text,bigint) TO service_role;

-- A single stream keeps full, per-user and seasonal XP calculations consistent.
CREATE VIEW public.statusxp_score_events WITH (security_invoker=true) AS
SELECT ua.user_id,ua.platform_id,ua.platform_game_id,ua.earned_at,
  a.base_status_xp*COALESCE(a.rarity_multiplier,1.0) AS points,1::integer achievement_count
FROM public.user_achievement_unlocks ua JOIN public.achievements a
  USING(platform_id,platform_game_id,platform_achievement_id)
WHERE a.include_in_score=true
UNION ALL
SELECT m.user_id,m.platform_id,m.platform_game_id,m.earned_at,m.base_status_xp,0::integer
FROM public.xbox_mythic_awards m;
GRANT SELECT ON public.statusxp_score_events TO anon,authenticated,service_role;
CREATE VIEW public.statusxp_possible_game_points WITH (security_invoker=true) AS
SELECT platform_id,platform_game_id,sum(points) AS potential FROM (
  SELECT platform_id,platform_game_id,base_status_xp AS points
    FROM public.achievements WHERE include_in_score=true
  UNION ALL
  SELECT platform_id,platform_game_id,base_status_xp FROM public.xbox_mythic_catalog
) catalog GROUP BY platform_id,platform_game_id;
GRANT SELECT ON public.statusxp_possible_game_points TO anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.calculate_statusxp_with_stacks(p_user_id uuid)
RETURNS TABLE(platform_id bigint,platform_game_id text,game_name text,achievements_earned integer,
  statusxp_raw integer,stack_index integer,stack_multiplier numeric,statusxp_effective integer)
LANGUAGE sql STABLE SET search_path='' AS $$
SELECT e.platform_id,e.platform_game_id,g.name,sum(e.achievement_count)::integer,
  sum(e.points)::integer,1::integer,1.0::numeric,sum(e.points)::integer
FROM public.statusxp_score_events e JOIN public.games g USING(platform_id,platform_game_id)
WHERE e.user_id=p_user_id GROUP BY e.platform_id,e.platform_game_id,g.name
ORDER BY sum(e.points)::integer DESC;
$$;

CREATE OR REPLACE VIEW statusxp_private.statusxp_refresh_totals AS
WITH scored_games AS (
 SELECT e.user_id,e.platform_id,e.platform_game_id,sum(e.points)::integer earned_xp
 FROM public.statusxp_score_events e JOIN public.games g USING(platform_id,platform_game_id)
 GROUP BY e.user_id,e.platform_id,e.platform_game_id
), scores AS (
 SELECT user_id,sum(earned_xp)::bigint total_statusxp,count(*)::integer total_game_entries
 FROM scored_games GROUP BY user_id
), owned AS (
 SELECT user_id,platform_id,platform_game_id FROM public.user_achievement_unlocks
 UNION SELECT user_id,platform_id,platform_game_id FROM public.xbox_mythic_awards
), potential AS (
 SELECT ug.user_id,sum(g.potential)::bigint potential_statusxp
 FROM owned ug JOIN public.statusxp_possible_game_points g USING(platform_id,platform_game_id)
 GROUP BY ug.user_id
)
SELECT p.id user_id,s.total_statusxp,COALESCE(t.potential_statusxp,0)::bigint potential_statusxp,s.total_game_entries
FROM scores s JOIN public.profiles_private p ON p.id=s.user_id LEFT JOIN potential t ON t.user_id=s.user_id
WHERE p.show_on_leaderboard=true AND p.merged_into_user_id IS NULL AND s.total_statusxp>0;

CREATE OR REPLACE FUNCTION public.refresh_statusxp_leaderboard_for_user(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.profiles_private WHERE id=p_user_id
   AND show_on_leaderboard=true AND merged_into_user_id IS NULL) THEN
   DELETE FROM public.leaderboard_cache WHERE user_id=p_user_id; RETURN;
 END IF;
 INSERT INTO public.leaderboard_cache(user_id,total_statusxp,potential_statusxp,total_game_entries,last_updated)
 SELECT p_user_id,sum(s.statusxp_effective)::bigint,
   (SELECT COALESCE(sum(g.potential),0)::bigint FROM (
      SELECT platform_id,platform_game_id FROM public.user_achievement_unlocks WHERE user_id=p_user_id
      UNION SELECT platform_id,platform_game_id FROM public.xbox_mythic_awards WHERE user_id=p_user_id
    ) ug JOIN public.statusxp_possible_game_points g USING(platform_id,platform_game_id)),
   count(*)::integer,now()
 FROM public.calculate_statusxp_with_stacks(p_user_id) s HAVING sum(s.statusxp_effective)>0
 ON CONFLICT(user_id) DO UPDATE SET total_statusxp=EXCLUDED.total_statusxp,
   potential_statusxp=EXCLUDED.potential_statusxp,total_game_entries=EXCLUDED.total_game_entries,last_updated=now();
 IF NOT FOUND THEN DELETE FROM public.leaderboard_cache WHERE user_id=p_user_id; END IF;
END;
$$;

CREATE VIEW public.xbox_mythic_leaderboard WITH (security_barrier=true) AS
SELECT x.user_id,x.display_name,x.avatar_url,count(m.user_id)::bigint mythic_count,
  x.achievement_count,x.total_games,s.synced_at
FROM public.xbox_leaderboard_cache x
JOIN public.profiles_private p ON p.id=x.user_id AND p.merged_into_user_id IS NULL
JOIN public.xbox_mythic_sync_state s ON s.user_id=x.user_id AND s.source_xuid=p.xbox_xuid::text
LEFT JOIN public.xbox_mythic_awards m ON m.user_id=x.user_id
GROUP BY x.user_id,x.display_name,x.avatar_url,x.achievement_count,x.total_games,s.synced_at;
GRANT SELECT ON public.xbox_mythic_leaderboard TO anon,authenticated,service_role;

CREATE FUNCTION public.get_xbox_mythic_stats(p_user_id uuid)
RETURNS TABLE(mythic_count bigint,mythics_synced boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
SELECT CASE WHEN s.user_id IS NOT NULL THEN
  (SELECT count(*) FROM public.xbox_mythic_awards m WHERE m.user_id=p.id) ELSE NULL END,
  s.user_id IS NOT NULL
FROM public.profiles_private p LEFT JOIN public.xbox_mythic_sync_state s
  ON s.user_id=p.id AND s.source_xuid=p.xbox_xuid::text
WHERE p.id=p_user_id AND p.merged_into_user_id IS NULL
  AND (p.show_on_leaderboard OR p.id=auth.uid() OR auth.role()='service_role');
$$;

CREATE FUNCTION public.get_xbox_mythic_leaderboard(limit_count integer DEFAULT 100,offset_count integer DEFAULT 0)
RETURNS TABLE(user_id uuid,display_name text,avatar_url text,mythic_count bigint,
 achievement_count bigint,total_games bigint,previous_rank integer,rank_change integer,is_new boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
WITH ranked AS (
 SELECT x.*,row_number() OVER(ORDER BY x.mythic_count DESC,x.achievement_count DESC,x.user_id) current_rank
 FROM public.xbox_mythic_leaderboard x
), previous AS (
 SELECT DISTINCT ON(h.user_id) h.user_id,h.rank FROM public.xbox_mythic_leaderboard_history h
 WHERE h.snapshot_at < now()-interval '1 hour' ORDER BY h.user_id,h.snapshot_at DESC
)
SELECT r.user_id,r.display_name,r.avatar_url,r.mythic_count,r.achievement_count,r.total_games,
  h.rank,COALESCE(h.rank-r.current_rank::integer,0),h.rank IS NULL
FROM ranked r LEFT JOIN previous h USING(user_id) ORDER BY r.current_rank
LIMIT greatest(limit_count,0) OFFSET greatest(offset_count,0);
$$;
CREATE FUNCTION public.get_xbox_mythic_period_leaderboard(p_period_type text DEFAULT 'weekly',
 limit_count integer DEFAULT 100,offset_count integer DEFAULT 0)
RETURNS TABLE(user_id uuid,display_name text,avatar_url text,period_gain bigint,mythic_count bigint,
 achievement_count bigint,total_games bigint,current_rank bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
WITH bounds AS (
 SELECT public.get_leaderboard_period_start(p_period_type,now()) start_at,
 CASE WHEN lower(p_period_type)='monthly' THEN interval '1 month' ELSE interval '7 days' END duration
), gains AS (
 SELECT m.user_id,count(*) gain FROM public.xbox_mythic_awards m CROSS JOIN bounds b
 WHERE m.earned_at>=b.start_at AND m.earned_at<b.start_at+b.duration GROUP BY m.user_id
), ranked AS (
 SELECT x.*,COALESCE(g.gain,0)::bigint gain,
 row_number() OVER(ORDER BY COALESCE(g.gain,0) DESC,x.mythic_count DESC,x.user_id) rank
 FROM public.xbox_mythic_leaderboard x LEFT JOIN gains g USING(user_id)
)
SELECT r.user_id,r.display_name,r.avatar_url,r.gain,r.mythic_count,r.achievement_count,r.total_games,r.rank
FROM ranked r ORDER BY r.rank LIMIT greatest(limit_count,0) OFFSET greatest(offset_count,0);
$$;
GRANT EXECUTE ON FUNCTION public.get_xbox_mythic_stats(uuid),
 public.get_xbox_mythic_leaderboard(integer,integer),public.get_xbox_mythic_period_leaderboard(text,integer,integer)
 TO anon,authenticated,service_role;

CREATE FUNCTION public.queue_xbox_mythic_score_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF TG_TABLE_NAME='user_xbox_mythics' THEN
   IF TG_OP='INSERT' OR (NEW.platform_id,NEW.source_xuid,NEW.earned_at)
     IS DISTINCT FROM (OLD.platform_id,OLD.source_xuid,OLD.earned_at) THEN
     INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform) VALUES(NEW.user_id,'statusxp','xbox');
   END IF;
 ELSIF NEW.base_status_xp IS DISTINCT FROM OLD.base_status_xp THEN
   INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform)
   SELECT DISTINCT user_id,'statusxp','xbox' FROM public.user_xbox_mythics
   WHERE platform_id=NEW.platform_id AND platform_game_id=NEW.platform_game_id;
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.queue_xbox_mythic_score_refresh() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER queue_mythic_unlock_refresh AFTER INSERT OR UPDATE ON public.user_xbox_mythics
FOR EACH ROW EXECUTE FUNCTION public.queue_xbox_mythic_score_refresh();
CREATE TRIGGER queue_mythic_rarity_refresh AFTER UPDATE ON public.xbox_mythic_catalog
FOR EACH ROW EXECUTE FUNCTION public.queue_xbox_mythic_score_refresh();

CREATE FUNCTION public.queue_xbox_mythic_account_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.xbox_xuid IS DISTINCT FROM OLD.xbox_xuid
   AND EXISTS(SELECT 1 FROM public.user_xbox_mythics WHERE user_id=NEW.id) THEN
   INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform) VALUES(NEW.id,'statusxp','xbox');
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.queue_xbox_mythic_account_refresh() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER queue_mythic_account_refresh AFTER UPDATE OF xbox_xuid ON public.profiles_private
FOR EACH ROW EXECUTE FUNCTION public.queue_xbox_mythic_account_refresh();

-- Existing clients retain their Gamerscore API. New clients use the named Mythic APIs.
-- Shared seasonal scoring and snapshots are patched below from inspected production definitions.
CREATE OR REPLACE FUNCTION public.get_statusxp_period_leaderboard(p_period_type text DEFAULT 'weekly'::text, limit_count integer DEFAULT 100, offset_count integer DEFAULT 0)
 RETURNS TABLE(user_id uuid, display_name text, avatar_url text, period_gain bigint, current_total bigint, baseline_total bigint, total_game_entries integer, current_rank bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
WITH bounds AS (
  SELECT
    CASE
      WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
      ELSE 'weekly'
    END AS period_type,
    public.get_leaderboard_period_start(p_period_type, now()) AS period_start
),
period_window AS (
  SELECT
    b.period_type,
    b.period_start,
    CASE
      WHEN b.period_type = 'monthly' THEN b.period_start + INTERVAL '1 month'
      ELSE b.period_start + INTERVAL '7 days'
    END AS period_end
  FROM bounds b
),
current_scores AS (
  SELECT
    lc.user_id,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_online_id
        WHEN 'xbox' THEN p.xbox_gamertag
        WHEN 'steam' THEN p.steam_display_name
      END,
      p.psn_online_id,
      p.xbox_gamertag,
      p.steam_display_name,
      p.display_name,
      p.username,
      'Player'::text
    ) AS display_name,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_avatar_url
        WHEN 'xbox' THEN p.xbox_avatar_url
        WHEN 'steam' THEN p.steam_avatar_url
      END,
      p.avatar_url
    ) AS avatar_url,
    lc.total_statusxp::bigint AS current_total,
    lc.total_game_entries
  FROM public.leaderboard_cache lc
  JOIN public.profiles p ON p.id = lc.user_id
  WHERE p.show_on_leaderboard = true
    AND lc.total_statusxp > 0
),
earned AS (
 SELECT e.user_id,sum(e.points)::bigint gain
 FROM public.statusxp_score_events e CROSS JOIN period_window w
 WHERE e.earned_at>=w.period_start AND e.earned_at<w.period_end GROUP BY e.user_id
),
ranked AS (
  SELECT
    cs.user_id,
    cs.display_name,
    cs.avatar_url,
    COALESCE(e.gain, 0)::bigint AS period_gain,
    cs.current_total,
    GREATEST(cs.current_total - COALESCE(e.gain, 0), 0)::bigint AS baseline_total,
    cs.total_game_entries,
    ROW_NUMBER() OVER (
      ORDER BY
        COALESCE(e.gain, 0) DESC,
        cs.current_total DESC,
        cs.user_id ASC
    )::bigint AS current_rank
  FROM current_scores cs
  LEFT JOIN earned e ON e.user_id = cs.user_id
)
SELECT
  r.user_id,
  r.display_name,
  r.avatar_url,
  r.period_gain,
  r.current_total,
  r.baseline_total,
  r.total_game_entries,
  r.current_rank
FROM ranked r
ORDER BY r.current_rank
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$function$;


CREATE OR REPLACE FUNCTION public.snapshot_xbox_leaderboard()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$

BEGIN

  INSERT INTO xbox_leaderboard_history (user_id, snapshot_at, rank, gamerscore, achievement_count, total_games)

  SELECT

    user_id,

    now(),

    ROW_NUMBER() OVER (ORDER BY gamerscore DESC, total_games DESC) as rank,

    gamerscore,

    achievement_count,

    total_games

  FROM xbox_leaderboard_cache

  ORDER BY rank;



  RAISE NOTICE 'Xbox leaderboard snapshot created at %', now();

  INSERT INTO public.xbox_mythic_leaderboard_history(user_id,snapshot_at,rank,mythic_count)
  SELECT x.user_id,now(),row_number() OVER(ORDER BY x.mythic_count DESC,x.achievement_count DESC,x.user_id)::integer,x.mythic_count
  FROM public.xbox_mythic_leaderboard x ON CONFLICT(user_id,snapshot_at) DO UPDATE
    SET rank=EXCLUDED.rank,mythic_count=EXCLUDED.mythic_count;
END;

$function$;


CREATE OR REPLACE FUNCTION public.get_leaderboard_hall_of_fame(p_period_type text DEFAULT 'weekly'::text, p_leaderboard_type text DEFAULT NULL::text, limit_count integer DEFAULT 100)
 RETURNS TABLE(leaderboard_type text, period_type text, period_start timestamp with time zone, period_end timestamp with time zone, winner_user_id uuid, winner_display_name text, winner_avatar_url text, winner_gain bigint, winner_current_score bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '25s'
AS $function$
WITH settings AS (
  SELECT CASE
    WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
    ELSE 'weekly'
  END AS period_type
),
request_limits AS (
  SELECT
    LEAST(GREATEST(limit_count, 0), 120)::int AS effective_limit,
    CASE
      WHEN LOWER(COALESCE(p_leaderboard_type, '')) IN ('statusxp', 'psn', 'xbox', 'steam')
        THEN 1
      ELSE 4
    END::int AS board_count
),
current_bounds AS (
  SELECT
    s.period_type,
    public.get_leaderboard_period_start(s.period_type, now()) AS current_period_start,
    CASE
      WHEN s.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', now())) AT TIME ZONE 'UTC')
      ELSE (
        (
          date_trunc('day', timezone('America/New_York', now()))
          - (((extract(dow from timezone('America/New_York', now()))::int - 2 + 7) % 7) * interval '1 day')
        ) AT TIME ZONE 'America/New_York'
      )
    END AS default_start
  FROM settings s
),
reset_floor AS (
  SELECT MAX(spo.start_at) AS weekly_floor
  FROM public.seasonal_period_overrides spo
  WHERE spo.period_type = 'weekly'
),
periods_needed AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly' THEN
        LEAST(
          GREATEST(((rl.effective_limit + rl.board_count - 1) / rl.board_count) + 2, 6),
          24
        )
      ELSE
        LEAST(
          GREATEST(((rl.effective_limit + rl.board_count - 1) / rl.board_count) + 2, 8),
          52
        )
    END AS n,
    rl.effective_limit
  FROM current_bounds cb
  CROSS JOIN request_limits rl
),
base_periods AS (
  SELECT
    cb.period_type,
    gs AS period_start,
    CASE
      WHEN cb.period_type = 'monthly' THEN gs + INTERVAL '1 month'
      ELSE gs + INTERVAL '7 days'
    END AS period_end
  FROM current_bounds cb
  CROSS JOIN periods_needed pn
  LEFT JOIN reset_floor rf ON TRUE
  CROSS JOIN LATERAL (
    SELECT generate_series(
      CASE
        WHEN cb.period_type = 'monthly'
          THEN (cb.default_start - (pn.n * INTERVAL '1 month'))
        ELSE (cb.default_start - (pn.n * INTERVAL '7 days'))
      END,
      CASE
        WHEN cb.period_type = 'monthly'
          THEN (cb.default_start - INTERVAL '1 month')
        ELSE (cb.default_start - INTERVAL '7 days')
      END,
      CASE
        WHEN cb.period_type = 'monthly' THEN INTERVAL '1 month'
        ELSE INTERVAL '7 days'
      END
    ) AS gs
  ) gen
  WHERE gs < cb.current_period_start
    AND (
      cb.period_type <> 'weekly'
      OR gs >= COALESCE(rf.weekly_floor, '-infinity'::timestamptz)
    )
),
override_periods AS (
  SELECT
    cb.period_type,
    spo.start_at AS period_start,
    COALESCE(
      spo.end_at,
      CASE
        WHEN cb.period_type = 'monthly' THEN spo.start_at + INTERVAL '1 month'
        ELSE spo.start_at + INTERVAL '7 days'
      END
    ) AS period_end
  FROM current_bounds cb
  JOIN public.seasonal_period_overrides spo
    ON spo.period_type = cb.period_type
  LEFT JOIN reset_floor rf ON TRUE
  WHERE spo.start_at < cb.current_period_start
    AND (
      cb.period_type <> 'weekly'
      OR spo.start_at >= COALESCE(rf.weekly_floor, '-infinity'::timestamptz)
    )
),
closed_periods AS (
  SELECT * FROM base_periods
  UNION
  SELECT * FROM override_periods
),
trimmed_periods AS (
  SELECT *
  FROM closed_periods
  ORDER BY period_start DESC
  LIMIT (SELECT n FROM periods_needed)
),
time_bounds AS (
  SELECT
    MIN(tp.period_start) AS min_start,
    MAX(tp.period_end) AS max_end
  FROM trimmed_periods tp
),
statusxp_gains AS (
 SELECT CASE WHEN cb.period_type='monthly'
   THEN date_trunc('month',timezone('UTC',e.earned_at)) AT TIME ZONE 'UTC'
   ELSE public.get_leaderboard_period_start('weekly',e.earned_at) END period_start,
 e.user_id,sum(e.points)::bigint gain
 FROM public.statusxp_score_events e CROSS JOIN current_bounds cb CROSS JOIN time_bounds tb
 WHERE e.earned_at>=tb.min_start AND e.earned_at<tb.max_end GROUP BY 1,2
),
psn_gains AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', ua.earned_at)) AT TIME ZONE 'UTC')
      ELSE public.get_leaderboard_period_start('weekly', ua.earned_at)
    END AS period_start,
    ua.user_id,
    COUNT(*) FILTER (WHERE a.is_platinum = true)::bigint AS gain
  FROM public.user_achievements ua
  JOIN public.achievements a ON
    a.platform_id = ua.platform_id
    AND a.platform_game_id = ua.platform_game_id
    AND a.platform_achievement_id = ua.platform_achievement_id
  CROSS JOIN current_bounds cb
  CROSS JOIN time_bounds tb
  WHERE ua.platform_id IN (1, 2, 5, 9)
    AND ua.earned_at IS NOT NULL
    AND ua.earned_at >= tb.min_start
    AND ua.earned_at < tb.max_end
  GROUP BY 1, 2
),
xbox_gains AS (
 SELECT CASE WHEN cb.period_type='monthly'
   THEN date_trunc('month',timezone('UTC',m.earned_at)) AT TIME ZONE 'UTC'
   ELSE public.get_leaderboard_period_start('weekly',m.earned_at) END period_start,
 m.user_id,count(*)::bigint gain
 FROM public.xbox_mythic_awards m CROSS JOIN current_bounds cb CROSS JOIN time_bounds tb
 WHERE m.earned_at>=tb.min_start AND m.earned_at<tb.max_end GROUP BY 1,2
),
steam_gains AS (
  SELECT
    CASE
      WHEN cb.period_type = 'monthly'
        THEN (date_trunc('month', timezone('UTC', ua.earned_at)) AT TIME ZONE 'UTC')
      ELSE public.get_leaderboard_period_start('weekly', ua.earned_at)
    END AS period_start,
    ua.user_id,
    COUNT(*)::bigint AS gain
  FROM public.user_achievements ua
  CROSS JOIN current_bounds cb
  CROSS JOIN time_bounds tb
  WHERE ua.platform_id = 4
    AND ua.earned_at IS NOT NULL
    AND ua.earned_at >= tb.min_start
    AND ua.earned_at < tb.max_end
  GROUP BY 1, 2
),
statusxp_candidates AS (
  SELECT
    'statusxp'::text AS leaderboard_type,
    tp.period_type,
    tp.period_start,
    tp.period_end,
    g.user_id,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_online_id
        WHEN 'xbox' THEN p.xbox_gamertag
        WHEN 'steam' THEN p.steam_display_name
      END,
      p.psn_online_id,
      p.xbox_gamertag,
      p.steam_display_name,
      p.display_name,
      p.username,
      'Player'::text
    ) AS display_name,
    COALESCE(
      CASE p.preferred_display_platform
        WHEN 'psn' THEN p.psn_avatar_url
        WHEN 'xbox' THEN p.xbox_avatar_url
        WHEN 'steam' THEN p.steam_avatar_url
      END,
      p.avatar_url
    ) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM trimmed_periods tp
  JOIN statusxp_gains g ON g.period_start = tp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
psn_candidates AS (
  SELECT
    'psn'::text AS leaderboard_type,
    tp.period_type,
    tp.period_start,
    tp.period_end,
    g.user_id,
    COALESCE(p.psn_online_id, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.psn_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM trimmed_periods tp
  JOIN psn_gains g ON g.period_start = tp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
xbox_candidates AS (
  SELECT
    'xbox'::text AS leaderboard_type,
    tp.period_type,
    tp.period_start,
    tp.period_end,
    g.user_id,
    COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.xbox_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM trimmed_periods tp
  JOIN xbox_gains g ON g.period_start = tp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
steam_candidates AS (
  SELECT
    'steam'::text AS leaderboard_type,
    tp.period_type,
    tp.period_start,
    tp.period_end,
    g.user_id,
    COALESCE(p.steam_display_name, p.display_name, p.username, 'Player'::text) AS display_name,
    COALESCE(p.steam_avatar_url, p.avatar_url) AS avatar_url,
    COALESCE(g.gain, 0)::bigint AS gain
  FROM trimmed_periods tp
  JOIN steam_gains g ON g.period_start = tp.period_start
  JOIN public.profiles p ON p.id = g.user_id
  WHERE p.show_on_leaderboard = true
),
all_candidates AS (
  SELECT * FROM statusxp_candidates
  UNION ALL
  SELECT * FROM psn_candidates
  UNION ALL
  SELECT * FROM xbox_candidates
  UNION ALL
  SELECT * FROM steam_candidates
),
filtered AS (
  SELECT ac.*
  FROM all_candidates ac
  WHERE (
    p_leaderboard_type IS NULL
    OR p_leaderboard_type = ''
    OR ac.leaderboard_type = LOWER(p_leaderboard_type)
  )
),
ranked AS (
  SELECT
    f.*,
    ROW_NUMBER() OVER (
      PARTITION BY f.leaderboard_type, f.period_start
      ORDER BY f.gain DESC, f.user_id ASC
    ) AS winner_rank
  FROM filtered f
),
winners AS (
  SELECT
    r.leaderboard_type,
    r.period_type,
    r.period_start,
    r.period_end,
    r.user_id AS winner_user_id,
    r.display_name AS winner_display_name,
    r.avatar_url AS winner_avatar_url,
    r.gain AS winner_gain
  FROM ranked r
  WHERE r.winner_rank = 1
),
enriched AS (
  SELECT
    w.*,
    COALESCE(
      CASE w.leaderboard_type
        WHEN 'statusxp' THEN (
          SELECT lh.total_statusxp::bigint
          FROM public.leaderboard_history lh
          WHERE lh.user_id = w.winner_user_id
            AND lh.snapshot_at < w.period_end
          ORDER BY lh.snapshot_at DESC
          LIMIT 1
        )
        WHEN 'psn' THEN (
          SELECT ph.platinum_count::bigint
          FROM public.psn_leaderboard_history ph
          WHERE ph.user_id = w.winner_user_id
            AND ph.snapshot_at < w.period_end
          ORDER BY ph.snapshot_at DESC
          LIMIT 1
        )
        WHEN 'xbox' THEN (SELECT count(*)::bigint FROM public.xbox_mythic_awards m WHERE m.user_id=w.winner_user_id AND m.earned_at<w.period_end)
        WHEN 'steam' THEN (
          SELECT sh.achievement_count::bigint
          FROM public.steam_leaderboard_history sh
          WHERE sh.user_id = w.winner_user_id
            AND sh.snapshot_at < w.period_end
          ORDER BY sh.snapshot_at DESC
          LIMIT 1
        )
        ELSE NULL
      END,
      CASE w.leaderboard_type
        WHEN 'statusxp' THEN (
          SELECT lc.total_statusxp::bigint
          FROM public.leaderboard_cache lc
          WHERE lc.user_id = w.winner_user_id
        )
        WHEN 'psn' THEN (
          SELECT plc.platinum_count::bigint
          FROM public.psn_leaderboard_cache plc
          WHERE plc.user_id = w.winner_user_id
        )
        WHEN 'xbox' THEN (SELECT count(*)::bigint FROM public.xbox_mythic_awards m WHERE m.user_id=w.winner_user_id)
        WHEN 'steam' THEN (
          SELECT slc.achievement_count::bigint
          FROM public.steam_leaderboard_cache slc
          WHERE slc.user_id = w.winner_user_id
        )
        ELSE 0::bigint
      END,
      0::bigint
    ) AS winner_current_score
  FROM winners w
)
SELECT
  e.leaderboard_type,
  e.period_type,
  e.period_start,
  e.period_end,
  e.winner_user_id,
  e.winner_display_name,
  e.winner_avatar_url,
  e.winner_gain,
  e.winner_current_score
FROM enriched e
ORDER BY e.period_end DESC, e.leaderboard_type ASC
LIMIT (SELECT effective_limit FROM periods_needed);
$function$;


CREATE OR REPLACE FUNCTION public.get_user_seasonal_game_breakdown(p_target_user_id uuid, p_board_type text DEFAULT 'statusxp'::text, p_period_type text DEFAULT 'weekly'::text, limit_count integer DEFAULT 200, offset_count integer DEFAULT 0)
 RETURNS TABLE(platform_id integer, platform_game_id text, game_name text, cover_url text, period_gain bigint, earned_count integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
WITH input AS (
  SELECT
    CASE
      WHEN LOWER(COALESCE(p_board_type, 'statusxp')) IN ('statusxp', 'psn', 'xbox', 'steam')
        THEN LOWER(COALESCE(p_board_type, 'statusxp'))
      ELSE 'statusxp'
    END AS board_type,
    CASE
      WHEN LOWER(COALESCE(p_period_type, 'weekly')) = 'monthly' THEN 'monthly'
      ELSE 'weekly'
    END AS period_type
),
period_window AS (
  SELECT
    i.period_type,
    public.get_leaderboard_period_start(i.period_type, now()) AS period_start,
    CASE
      WHEN i.period_type = 'monthly'
        THEN public.get_leaderboard_period_start(i.period_type, now()) + INTERVAL '1 month'
      ELSE public.get_leaderboard_period_start(i.period_type, now()) + INTERVAL '7 days'
    END AS period_end
  FROM input i
),
target_user AS (
  SELECT p.id AS user_id
  FROM public.profiles p
  WHERE p.id = p_target_user_id
    AND (p.show_on_leaderboard = true OR p.id = auth.uid())
),
breakdown_rows AS (
  SELECT e.platform_id,e.platform_game_id,e.points::numeric contribution
  FROM public.statusxp_score_events e JOIN target_user tu ON tu.user_id=e.user_id
  CROSS JOIN input i CROSS JOIN period_window w
  WHERE i.board_type='statusxp' AND e.earned_at>=w.period_start AND e.earned_at<w.period_end

  UNION ALL

  SELECT
    ua.platform_id,
    ua.platform_game_id,
    1::numeric AS contribution
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  JOIN target_user tu ON tu.user_id = ua.user_id
  CROSS JOIN input i
  CROSS JOIN period_window w
  WHERE i.board_type = 'psn'
    AND ua.platform_id IN (1, 2, 5, 9)
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
    AND a.is_platinum = true

  UNION ALL

  SELECT m.platform_id,m.platform_game_id,1::numeric contribution
  FROM public.xbox_mythic_awards m JOIN target_user tu ON tu.user_id=m.user_id
  CROSS JOIN input i CROSS JOIN period_window w
  WHERE i.board_type='xbox' AND m.earned_at>=w.period_start AND m.earned_at<w.period_end

  UNION ALL

  SELECT
    ua.platform_id,
    ua.platform_game_id,
    1::numeric AS contribution
  FROM public.user_achievements ua
  JOIN target_user tu ON tu.user_id = ua.user_id
  CROSS JOIN input i
  CROSS JOIN period_window w
  WHERE i.board_type = 'steam'
    AND ua.platform_id = 4
    AND ua.earned_at >= w.period_start
    AND ua.earned_at < w.period_end
),
grouped AS (
  SELECT
    br.platform_id,
    br.platform_game_id,
    SUM(br.contribution)::bigint AS period_gain,
    COUNT(*)::integer AS earned_count
  FROM breakdown_rows br
  GROUP BY br.platform_id, br.platform_game_id
)
SELECT
  g2.platform_id::integer,
  g2.platform_game_id,
  COALESCE(g.name, g2.platform_game_id)::text AS game_name,
  g.cover_url,
  g2.period_gain,
  g2.earned_count
FROM grouped g2
LEFT JOIN public.games g
  ON g.platform_id = g2.platform_id
 AND g.platform_game_id = g2.platform_game_id
ORDER BY
  g2.period_gain DESC,
  g2.earned_count DESC,
  COALESCE(g.name, g2.platform_game_id) ASC
LIMIT GREATEST(limit_count, 0)
OFFSET GREATEST(offset_count, 0);
$function$;

COMMIT;
