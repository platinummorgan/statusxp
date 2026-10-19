-- Run inside the candidate migration transaction; all fixtures roll back.
INSERT INTO auth.users(id,email,raw_user_meta_data)
SELECT ('00000000-0000-4000-8000-00000000'||n)::uuid,'refresh-'||n||'@statusxp.invalid','{}'::jsonb FROM generate_series(9941,9944)n;
UPDATE public.profiles_private SET psn_sync_status='error',psn_sync_progress=0,psn_sync_error='Sync data saved; leaderboard refresh pending. A background retry is queued.',last_psn_sync_at='2020-01-01' WHERE id IN(SELECT ('00000000-0000-4000-8000-00000000'||n)::uuid FROM generate_series(9941,9944)n);
INSERT INTO public.psn_sync_logs(user_id,sync_type,status,started_at,completed_at,error_message,games_processed,trophies_synced)
SELECT ('00000000-0000-4000-8000-00000000'||n)::uuid,'full','failed',now()-interval '2 minutes',now()-interval '1 minute','Sync data saved; leaderboard refresh pending. A background retry is queued.',1,5 FROM generate_series(9941,9944)n;
INSERT INTO public.leaderboard_refresh_jobs(user_id,kind,source_platform,created_at,completed_at)
SELECT ('00000000-0000-4000-8000-00000000'||n)::uuid,kind,'psn',now()-interval '90 seconds',CASE WHEN n=9942 AND kind='psn' THEN NULL ELSE now() END FROM generate_series(9941,9944)n CROSS JOIN(VALUES('statusxp'),('psn'))k(kind);
-- A newer sync and a different real failure must never be overwritten.
INSERT INTO public.psn_sync_logs(user_id,sync_type,status,started_at) VALUES('00000000-0000-4000-8000-000000009943','full','syncing',now());
UPDATE public.profiles_private SET psn_sync_status='syncing',psn_sync_progress=27,psn_sync_error=NULL WHERE id='00000000-0000-4000-8000-000000009943';
UPDATE public.psn_sync_logs SET error_message='A trophy import failed' WHERE user_id='00000000-0000-4000-8000-000000009944';
SELECT statusxp_private.recover_finished_psn_refreshes();
DO $$ BEGIN
 ASSERT (SELECT psn_sync_status='success' AND psn_sync_progress=100 AND last_psn_sync_at=now()-interval '1 minute' FROM public.profiles_private WHERE id='00000000-0000-4000-8000-000000009941');
 ASSERT (SELECT status='completed' AND trophies_synced=5 AND completed_at=now()-interval '1 minute' FROM public.psn_sync_logs WHERE user_id='00000000-0000-4000-8000-000000009941');
 ASSERT (SELECT psn_sync_status='error' FROM public.profiles_private WHERE id='00000000-0000-4000-8000-000000009942');
 ASSERT (SELECT psn_sync_status='syncing' AND psn_sync_progress=27 FROM public.profiles_private WHERE id='00000000-0000-4000-8000-000000009943');
 ASSERT (SELECT status='failed' AND error_message='A trophy import failed' FROM public.psn_sync_logs WHERE user_id='00000000-0000-4000-8000-000000009944');
 ASSERT statusxp_private.recover_finished_psn_refreshes()=0;
 ASSERT NOT has_function_privilege('authenticated','statusxp_private.recover_finished_psn_refreshes()','EXECUTE');
 ASSERT NOT has_function_privilege('service_role','statusxp_private.recover_finished_psn_refreshes()','EXECUTE');
END $$;
-- Background completion after an earlier failed recovery is picked up next run.
UPDATE public.leaderboard_refresh_jobs SET completed_at=now() WHERE user_id='00000000-0000-4000-8000-000000009942' AND completed_at IS NULL;
SELECT statusxp_private.recover_finished_psn_refreshes();
DO $$ BEGIN ASSERT (SELECT psn_sync_status='success' FROM public.profiles_private WHERE id='00000000-0000-4000-8000-000000009942'); END $$;
