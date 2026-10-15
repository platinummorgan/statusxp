-- Verified legacy Xbox imports stored as PS4. Reuse existing Xbox definitions;
-- never infer ownership from a game name or manufacture PSN trophies.
BEGIN;
SET LOCAL lock_timeout = '10s';
SET LOCAL statement_timeout = '60s';
LOCK TABLE public.games, public.achievements, public.user_progress,
  public.user_achievements, public.achievement_comments, public.flex_room_data
  IN SHARE ROW EXCLUSIVE MODE;

CREATE TEMP TABLE platform_repair_map ON COMMIT DROP AS
SELECT g.platform_id source_platform, g.platform_game_id, x.platform_id target_platform
FROM public.games g
JOIN public.games x ON x.platform_game_id=g.platform_game_id AND x.platform_id IN(10,11,12)
WHERE g.platform_id=2 AND g.metadata->>'xbox_title_id'=g.platform_game_id
AND g.platform_game_id IN('1046363979','1211542442','1386529057','148078765',
 '1692871917','1813362885','269700535','367004125','398011207','530462567','927474846','996030243');

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM platform_repair_map GROUP BY platform_game_id HAVING count(*)<>1)
 OR EXISTS(SELECT 1 FROM public.achievements a JOIN platform_repair_map m
 ON a.platform_id=m.source_platform AND a.platform_game_id=m.platform_game_id
 LEFT JOIN public.achievements d ON d.platform_id=m.target_platform
 AND d.platform_game_id=a.platform_game_id AND d.platform_achievement_id=a.platform_achievement_id
 WHERE d.platform_id IS NULL OR d.name IS DISTINCT FROM a.name
 OR a.metadata->>'gamerscore' IS NULL OR a.metadata->>'psn_trophy_type' IS NOT NULL)
 THEN RAISE EXCEPTION 'Platform repair ownership validation failed'; END IF;
END $$;

CREATE TEMP TABLE platform_repair_expected ON COMMIT DROP AS
SELECT ua.user_id,m.target_platform platform_id,ua.platform_game_id,ua.platform_achievement_id,
 min(ua.earned_at) earned_at
FROM public.user_achievements ua JOIN platform_repair_map m
 ON ua.platform_game_id=m.platform_game_id AND ua.platform_id IN(m.source_platform,m.target_platform)
GROUP BY ua.user_id,m.target_platform,ua.platform_game_id,ua.platform_achievement_id;

CREATE TEMP TABLE platform_repair_users ON COMMIT DROP AS
SELECT p.user_id,m.target_platform platform_id,p.platform_game_id
FROM public.user_progress p JOIN platform_repair_map m
 ON p.platform_id=m.source_platform AND p.platform_game_id=m.platform_game_id
UNION
SELECT a.user_id,m.target_platform,a.platform_game_id
FROM public.user_achievements a JOIN platform_repair_map m
 ON a.platform_id=m.source_platform AND a.platform_game_id=m.platform_game_id;

INSERT INTO public.user_achievements AS dest
 (user_id,platform_id,platform_game_id,platform_achievement_id,earned_at,synced_at)
SELECT ua.user_id,m.target_platform,ua.platform_game_id,ua.platform_achievement_id,ua.earned_at,ua.synced_at
FROM public.user_achievements ua JOIN platform_repair_map m
 ON ua.platform_id=m.source_platform AND ua.platform_game_id=m.platform_game_id
ON CONFLICT(user_id,platform_id,platform_game_id,platform_achievement_id) DO UPDATE
SET earned_at=least(dest.earned_at,excluded.earned_at),synced_at=greatest(dest.synced_at,excluded.synced_at);

INSERT INTO public.user_progress AS dest
 (user_id,platform_id,platform_game_id,current_score,achievements_earned,total_achievements,
 completion_percentage,first_played_at,last_played_at,synced_at,metadata,last_achievement_earned_at)
SELECT p.user_id,m.target_platform,p.platform_game_id,p.current_score,p.achievements_earned,
 p.total_achievements,p.completion_percentage,p.first_played_at,p.last_played_at,p.synced_at,
 p.metadata,p.last_achievement_earned_at
FROM public.user_progress p JOIN platform_repair_map m
 ON p.platform_id=m.source_platform AND p.platform_game_id=m.platform_game_id
ON CONFLICT(user_id,platform_id,platform_game_id) DO UPDATE SET
 current_score=greatest(dest.current_score,excluded.current_score),
 achievements_earned=greatest(dest.achievements_earned,excluded.achievements_earned),
 total_achievements=greatest(dest.total_achievements,excluded.total_achievements),
 first_played_at=least(dest.first_played_at,excluded.first_played_at),
 last_played_at=greatest(dest.last_played_at,excluded.last_played_at),
 synced_at=greatest(dest.synced_at,excluded.synced_at),
 metadata=CASE WHEN excluded.synced_at>dest.synced_at THEN dest.metadata||excluded.metadata
 ELSE excluded.metadata||dest.metadata END,
 last_achievement_earned_at=greatest(dest.last_achievement_earned_at,excluded.last_achievement_earned_at);

-- Retain provider summary counts if an import is incomplete, but never undercount
-- the actual union of persisted achievements.
WITH earned AS (
 SELECT ua.user_id,ua.platform_id,ua.platform_game_id,count(*)::integer n,
 sum(coalesce((a.metadata->>'gamerscore')::integer,a.score_value,0))::integer score,
 max(ua.earned_at) latest
 FROM public.user_achievements ua JOIN platform_repair_map m
 ON ua.platform_id=m.target_platform AND ua.platform_game_id=m.platform_game_id
 JOIN public.achievements a ON a.platform_id=ua.platform_id AND a.platform_game_id=ua.platform_game_id
 AND a.platform_achievement_id=ua.platform_achievement_id
 JOIN platform_repair_users u ON u.user_id=ua.user_id AND u.platform_id=ua.platform_id
 AND u.platform_game_id=ua.platform_game_id
 GROUP BY ua.user_id,ua.platform_id,ua.platform_game_id
), totals AS (
 SELECT a.platform_id,a.platform_game_id,count(*)::integer n FROM public.achievements a
 JOIN platform_repair_map m ON a.platform_id=m.target_platform AND a.platform_game_id=m.platform_game_id
 GROUP BY a.platform_id,a.platform_game_id
)
UPDATE public.user_progress p SET
 achievements_earned=greatest(p.achievements_earned,e.n),
 current_score=greatest(p.current_score,e.score),
 total_achievements=greatest(p.total_achievements,t.n,e.n),
 completion_percentage=round(100.0*greatest(p.achievements_earned,e.n)/greatest(p.total_achievements,t.n,e.n),2),
 last_achievement_earned_at=greatest(p.last_achievement_earned_at,e.latest)
FROM earned e JOIN totals t USING(platform_id,platform_game_id)
WHERE p.user_id=e.user_id AND p.platform_id=e.platform_id AND p.platform_game_id=e.platform_game_id;

UPDATE public.achievement_comments c SET platform_id=m.target_platform
FROM platform_repair_map m WHERE c.platform_id=m.source_platform AND c.platform_game_id=m.platform_game_id;

DO $$ DECLARE prefix text; BEGIN
 FOREACH prefix IN ARRAY ARRAY['flex_of_all_time','rarest_flex','most_time_sunk','sweatiest_platinum'] LOOP
 EXECUTE format('UPDATE public.flex_room_data f SET %I=m.target_platform FROM platform_repair_map m WHERE f.%I=m.source_platform AND f.%I=m.platform_game_id',prefix||'_platform_id',prefix||'_platform_id',prefix||'_platform_game_id');
 END LOOP;
END $$;

DELETE FROM public.user_achievements a USING platform_repair_map m
WHERE a.platform_id=m.source_platform AND a.platform_game_id=m.platform_game_id;
DELETE FROM public.user_progress p USING platform_repair_map m
WHERE p.platform_id=m.source_platform AND p.platform_game_id=m.platform_game_id;
DELETE FROM public.achievements a USING platform_repair_map m
WHERE a.platform_id=m.source_platform AND a.platform_game_id=m.platform_game_id;
DELETE FROM public.games g USING platform_repair_map m
WHERE g.platform_id=m.source_platform AND g.platform_game_id=m.platform_game_id;

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM platform_repair_expected e LEFT JOIN public.user_achievements a
 USING(user_id,platform_id,platform_game_id,platform_achievement_id)
 WHERE a.user_id IS NULL OR a.earned_at IS DISTINCT FROM e.earned_at)
 THEN RAISE EXCEPTION 'Platform repair lost an achievement or earned date'; END IF;
END $$;

-- Stop this specific legacy import defect at the database boundary.
ALTER TABLE public.achievements ADD CONSTRAINT psn_achievements_no_xbox_gamerscore
 CHECK(platform_id NOT IN(1,2,5,9) OR metadata->>'gamerscore' IS NULL) NOT VALID;
ALTER TABLE public.achievements VALIDATE CONSTRAINT psn_achievements_no_xbox_gamerscore;

SELECT public.auto_refresh_all_leaderboards();
COMMIT;
