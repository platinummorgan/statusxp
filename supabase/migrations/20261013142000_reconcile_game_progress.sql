BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='60s';
SET LOCAL work_mem='64MB';
SET LOCAL enable_nestloop=off;
LOCK TABLE public.user_progress,public.user_achievements,public.achievements IN SHARE ROW EXCLUSIVE MODE;

CREATE TEMP TABLE repair_earned ON COMMIT DROP AS
SELECT ua.user_id,ua.platform_id,ua.platform_game_id,count(*)::integer earned,
 max(ua.earned_at) latest,
 count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='bronze') bronze,
 count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='silver') silver,
 count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='gold') gold,
 count(*) FILTER(WHERE a.metadata->>'psn_trophy_type'='platinum' OR a.is_platinum) platinum,
 sum(coalesce(a.score_value,0))::integer score
FROM public.user_achievements ua JOIN public.achievements a
 USING(platform_id,platform_game_id,platform_achievement_id)
GROUP BY ua.user_id,ua.platform_id,ua.platform_game_id;
CREATE TEMP TABLE repair_definitions ON COMMIT DROP AS
SELECT platform_id,platform_game_id,count(*)::integer total
FROM public.achievements GROUP BY platform_id,platform_game_id;

INSERT INTO public.user_progress(user_id,platform_id,platform_game_id,achievements_earned,
 total_achievements,completion_percentage,last_achievement_earned_at,current_score,metadata)
SELECT e.user_id,e.platform_id,e.platform_game_id,e.earned,d.total,
 round(100.0*e.earned/d.total,2),e.latest,
 CASE WHEN e.platform_id IN(10,11,12) THEN e.score ELSE 0 END,
 jsonb_build_object('summary_reconstructed_from_earned',true,'total_achievements_known',true,
 'achievement_import_complete',false,'sync_failed',true,
 'sync_error','Game summary restored from saved achievements; provider reconciliation required',
 'bronze_trophies',e.bronze,'silver_trophies',e.silver,'gold_trophies',e.gold,
 'platinum_trophies',e.platinum,'has_platinum',e.platinum>0)
FROM repair_earned e JOIN repair_definitions d USING(platform_id,platform_game_id)
ON CONFLICT(user_id,platform_id,platform_game_id) DO NOTHING;

-- Saved rows prove a minimum, not the completeness of an external provider's
-- catalogue. Keep larger provider totals/counts and flag incomplete detail.
WITH source AS (
 SELECT p.user_id,p.platform_id,p.platform_game_id,
 greatest(coalesce(p.achievements_earned,0),coalesce(e.earned,0)) earned,
 greatest(coalesce(p.total_achievements,0),coalesce(d.total,0)) total,
 coalesce(e.earned,0) saved,e.latest
 FROM public.user_progress p LEFT JOIN repair_earned e USING(user_id,platform_id,platform_game_id)
 LEFT JOIN repair_definitions d USING(platform_id,platform_game_id)
 WHERE p.achievements_earned IS DISTINCT FROM coalesce(e.earned,0)
 OR coalesce(p.total_achievements,0)=0 AND (p.achievements_earned>0 OR d.total>0)
)
UPDATE public.user_progress p SET achievements_earned=s.earned,total_achievements=s.total,
 completion_percentage=CASE WHEN s.total>=s.earned AND s.total>0
 THEN round(100.0*s.earned/s.total,2) ELSE p.completion_percentage END,
 last_achievement_earned_at=greatest(p.last_achievement_earned_at,s.latest),
 metadata=coalesce(p.metadata,'{}'::jsonb)||jsonb_build_object(
 'total_achievements_known',s.total>0,
 'achievement_import_complete',false,
 'saved_achievement_count_at_repair',s.saved,
 'sync_failed',true,
 'sync_error','Achievement details need provider reconciliation; reported progress retained')
FROM source s WHERE p.user_id=s.user_id AND p.platform_id=s.platform_id AND p.platform_game_id=s.platform_game_id;

DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM repair_earned e LEFT JOIN public.user_progress p
 USING(user_id,platform_id,platform_game_id)
 WHERE p.user_id IS NULL OR p.achievements_earned<e.earned)
 THEN RAISE EXCEPTION 'Saved achievement summary reconciliation failed'; END IF;
END $$;
SELECT public.auto_refresh_all_leaderboards();
COMMIT;
