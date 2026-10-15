-- Public source excludes account-specific recovery data; original retained in private audit archive.
-- Confirmed provider unlocks with absent or sentinel timestamps, retained
-- in the audited provider responses. No earned date is supplied or inferred.
BEGIN;
SET LOCAL lock_timeout='10s';
SET LOCAL statement_timeout='60s';
CREATE TEMP TABLE reviewed_undated(user_id uuid,platform_id bigint,platform_game_id text,platform_achievement_id text,evidence_source text,xuid text) ON COMMIT DROP;
-- One-time account-specific data was applied privately in production.

DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM reviewed_undated r LEFT JOIN public.profiles_private p ON p.id=r.user_id LEFT JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id) WHERE p.id IS NULL OR p.xbox_xuid IS DISTINCT FROM r.xuid OR a.platform_id IS NULL),'Reviewed account binding or definition changed';
END $$;
INSERT INTO public.user_undated_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,evidence_source)
SELECT r.user_id,r.platform_id,r.platform_game_id,r.platform_achievement_id,r.evidence_source FROM reviewed_undated r
WHERE NOT EXISTS(SELECT 1 FROM public.user_achievements d WHERE d.user_id=r.user_id AND d.platform_id=r.platform_id AND d.platform_game_id=r.platform_game_id AND d.platform_achievement_id=r.platform_achievement_id)
ON CONFLICT(user_id,platform_id,platform_game_id,platform_achievement_id) DO NOTHING;
WITH counts AS(
 SELECT u.user_id,u.platform_id,u.platform_game_id,count(*)::integer earned FROM public.user_achievement_unlocks u
 JOIN (SELECT DISTINCT user_id,platform_id,platform_game_id FROM reviewed_undated) r USING(user_id,platform_id,platform_game_id)
 GROUP BY u.user_id,u.platform_id,u.platform_game_id
)
UPDATE public.user_progress p SET achievements_earned=greatest(p.achievements_earned,c.earned),
 metadata=coalesce(p.metadata,'{}'::jsonb)||jsonb_build_object('achievement_import_complete',c.earned>=p.achievements_earned,'sync_failed',c.earned<p.achievements_earned,'sync_error',CASE WHEN c.earned<p.achievements_earned THEN 'Provider progress still exceeds confirmed unlocks' ELSE NULL END,'undated_unlocks_supported',true)
FROM counts c WHERE p.user_id=c.user_id AND p.platform_id=c.platform_id AND p.platform_game_id=c.platform_game_id;
SELECT public.auto_refresh_all_leaderboards();
COMMIT;
