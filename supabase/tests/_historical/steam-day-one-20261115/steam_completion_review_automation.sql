BEGIN;
DO $$
DECLARE j public.steam_completion_review_jobs%ROWTYPE;v_proposal jsonb;
BEGIN
 ASSERT NOT has_table_privilege('authenticated','public.steam_completion_review_jobs','SELECT');
 ASSERT NOT has_function_privilege('anon','public.claim_steam_completion_review_job()','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','public.finish_steam_completion_review_job(text,uuid,jsonb,text)','EXECUTE');
 INSERT INTO public.games(platform_id,platform_game_id,name)
 VALUES(4,'review_fixture_source','Membership Review Fixture'),(4,'review_fixture_target','Membership Review Fixture');
 INSERT INTO public.achievements(platform_id,platform_game_id,platform_achievement_id,name,description,rarity_global)
 VALUES(4,'review_fixture_source','S_BASE','Base','Original requirement',1),
 (4,'review_fixture_source','S_DLC','Expansion','Extra requirement',0),
 (4,'review_fixture_target','T_BASE','Base','Original requirement',0),
 (4,'review_fixture_target','T_DLC','Expansion','Extra requirement',100);
 PERFORM public.review_steam_completion_set('review_fixture_source',ARRAY['S_BASE'],ARRAY['S_DLC'],
  '{"scope":"day_one_base_game","sources":["https://example.com/reviewed-original"]}'::jsonb);
 INSERT INTO public.steam_completion_catalog(platform_game_id,observed_ids)
 VALUES('review_fixture_target',ARRAY['T_BASE','T_DLC']);
 ASSERT EXISTS(SELECT 1 FROM public.steam_completion_review_jobs WHERE platform_game_id='review_fixture_target');
 UPDATE public.steam_completion_review_jobs SET next_attempt_at=now()+interval '1 day'
 WHERE platform_game_id<>'review_fixture_target';
 SELECT * INTO j FROM public.claim_steam_completion_review_job();
 ASSERT j.platform_game_id='review_fixture_target' AND j.status='processing';
 ASSERT NOT EXISTS(SELECT 1 FROM public.claim_steam_completion_review_job());
 v_proposal:='{"app_id":"review_fixture_target","status":"ready_for_review","coverage_complete":true,"observed_ids":["T_BASE","T_DLC"],"native_definitions":[{"id":"T_BASE","name":"Base","description":"Original requirement"},{"id":"T_DLC","name":"Expansion","description":"Extra requirement"}]}'::jsonb;
 ASSERT public.finish_steam_completion_review_job(j.platform_game_id,j.lease_token,v_proposal,NULL);
 ASSERT (SELECT review_state='verified' AND required_ids=ARRAY['T_BASE'] AND excluded_ids=ARRAY['T_DLC']
  AND estimated_rarity=0 AND base_status_xp=58 FROM public.steam_completion_catalog WHERE platform_game_id=j.platform_game_id);
 ASSERT (SELECT status='approved' FROM public.steam_completion_review_jobs WHERE platform_game_id=j.platform_game_id);
 ASSERT NOT EXISTS(SELECT 1 FROM public.steam_completion_progress WHERE platform_game_id=j.platform_game_id),
  'Membership review must never fabricate user qualification';

 -- Changed requirements prevent automatic copying despite identical title/counts.
 UPDATE public.steam_completion_catalog SET review_state='pending',evidence='{}' WHERE platform_game_id=j.platform_game_id;
 UPDATE public.achievements SET description='Different requirement' WHERE platform_game_id=j.platform_game_id AND platform_achievement_id='T_BASE';
 UPDATE public.steam_completion_review_jobs SET next_attempt_at=now() WHERE platform_game_id=j.platform_game_id;
 SELECT * INTO j FROM public.claim_steam_completion_review_job();
 ASSERT public.finish_steam_completion_review_job(j.platform_game_id,j.lease_token,v_proposal,NULL);
 ASSERT (SELECT review_state='pending' FROM public.steam_completion_catalog WHERE platform_game_id=j.platform_game_id);
 ASSERT (SELECT status='ready_for_review' FROM public.steam_completion_review_jobs WHERE platform_game_id=j.platform_game_id);
 UPDATE public.achievements SET description='Original requirement' WHERE platform_game_id=j.platform_game_id AND platform_achievement_id='T_BASE';

 -- Hand-reviewed exceptions remain exceptions even when an identical template exists.
 UPDATE public.steam_completion_catalog SET review_state='needs_review',evidence='{"reason":"manual exception"}' WHERE platform_game_id=j.platform_game_id;
 UPDATE public.steam_completion_review_jobs SET next_attempt_at=now() WHERE platform_game_id=j.platform_game_id;
 SELECT * INTO j FROM public.claim_steam_completion_review_job();
 ASSERT public.finish_steam_completion_review_job(j.platform_game_id,j.lease_token,v_proposal,NULL);
 ASSERT (SELECT review_state='needs_review' AND evidence->>'reason'='manual exception'
  FROM public.steam_completion_catalog WHERE platform_game_id=j.platform_game_id);

 -- Old workers cannot publish after schema changes replace their lease.
 UPDATE public.steam_completion_review_jobs SET next_attempt_at=now() WHERE platform_game_id=j.platform_game_id;
 SELECT * INTO j FROM public.claim_steam_completion_review_job();
 UPDATE public.steam_completion_catalog SET observed_ids=ARRAY['T_BASE','T_DLC','T_NEW'] WHERE platform_game_id=j.platform_game_id;
 ASSERT NOT public.finish_steam_completion_review_job(j.platform_game_id,j.lease_token,v_proposal,NULL);
 SELECT * INTO j FROM public.claim_steam_completion_review_job();
 UPDATE public.steam_completion_review_jobs SET leased_until=now()-interval '1 second' WHERE platform_game_id=j.platform_game_id;
 ASSERT NOT public.finish_steam_completion_review_job(j.platform_game_id,j.lease_token,v_proposal,NULL);

 -- A provider failure leaves a bounded retry without raw credentials/errors.
 SELECT * INTO j FROM public.claim_steam_completion_review_job();
 ASSERT public.finish_steam_completion_review_job(j.platform_game_id,j.lease_token,NULL,'secret raw provider error');
 ASSERT (SELECT status='error' AND next_attempt_at>now()+interval '29 minutes'
  AND last_error='Provider evidence or catalog unavailable' FROM public.steam_completion_review_jobs WHERE platform_game_id=j.platform_game_id);
END $$;
ROLLBACK;
