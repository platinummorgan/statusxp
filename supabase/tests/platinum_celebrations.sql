BEGIN;
DO $$ DECLARE v_user uuid; v_other uuid; BEGIN
 SELECT u.user_id INTO v_user FROM public.user_achievements u JOIN public.achievements a USING(platform_id,platform_game_id,platform_achievement_id)
 JOIN public.profiles_private p ON p.id=u.user_id
 WHERE a.is_platinum AND u.platform_id IN(1,2,5,9) AND coalesce(p.psn_sync_status,'') NOT IN('pending','syncing','cancelling')
 GROUP BY u.user_id HAVING count(*)>=3 ORDER BY count(*) LIMIT 1;
 ASSERT v_user IS NOT NULL,'An existing PSN test account with 3 platinums is required';
 SELECT id INTO v_other FROM auth.users WHERE id<>v_user LIMIT 1;
 PERFORM set_config('platinum.test.owner',v_user::text,true);
 PERFORM set_config('platinum.test.other',v_other::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'role','authenticated')::text,true);
 ASSERT NOT has_function_privilege('anon','public.get_my_platinum_cards(integer,integer)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','public.reserve_platinum_art(uuid,uuid,text,bigint,text)','EXECUTE');
 ASSERT NOT has_table_privilege('authenticated','statusxp_private.platinum_art_requests','SELECT');
 ASSERT NOT has_table_privilege('authenticated','statusxp_private.platinum_celebration_state','UPDATE');
 ASSERT NOT (SELECT public FROM storage.buckets WHERE id='platinum-art');
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE b jsonb; second jsonb; cards jsonb; c jsonb; f jsonb; BEGIN
 cards:=public.get_my_platinum_cards(0,2); ASSERT jsonb_array_length(cards)=2;
 ASSERT (cards->0->>'platinum_number')::integer>(cards->1->>'platinum_number')::integer;
 c:=cards->0;
 f:=public.get_my_platinum_card((c->>'platform_id')::bigint,c->>'platform_game_id',c->>'platform_achievement_id');
 ASSERT f=c;
 b:=public.discover_my_platinum_celebration();ASSERT (b->>'historical')::boolean;ASSERT (b->>'count')::integer>=3;
 second:=public.discover_my_platinum_celebration();ASSERT b=second,'An unacknowledged batch must survive retries';
 ASSERT NOT public.acknowledge_my_platinum_celebration('00000000-0000-4000-8000-000000000099');
 PERFORM set_config('platinum.test.batch',b->>'id',true);
END $$;
SET LOCAL ROLE postgres;
DO $$ BEGIN
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('platinum.test.other'),'role','authenticated')::text,true);
END $$;
SET LOCAL ROLE authenticated;
DO $$ BEGIN ASSERT NOT public.acknowledge_my_platinum_celebration(current_setting('platinum.test.batch')::uuid),'Other users must not acknowledge owner batch'; END $$;
SET LOCAL ROLE postgres;
DO $$ BEGIN
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',current_setting('platinum.test.owner'),'role','authenticated')::text,true);
END $$;
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 ASSERT public.acknowledge_my_platinum_celebration(current_setting('platinum.test.batch')::uuid);
 ASSERT public.discover_my_platinum_celebration() IS NULL,'Another sync must not repeat acknowledged platinums';
END $$;
SET LOCAL ROLE postgres;
-- Re-expose one already earned recent trophy as a newly imported record, without
-- adding or deleting any user achievements. All fixture changes roll back.
DO $$ DECLARE s record; BEGIN
 SELECT * INTO s FROM statusxp_private.platinum_celebration_seen WHERE user_id=current_setting('platinum.test.owner')::uuid LIMIT 1;
 DELETE FROM statusxp_private.platinum_celebration_seen WHERE user_id=s.user_id AND platform_id=s.platform_id AND platform_game_id=s.platform_game_id AND platform_achievement_id=s.platform_achievement_id;
 UPDATE public.user_achievements SET earned_at=now()-interval '1 day' WHERE user_id=s.user_id AND platform_id=s.platform_id AND platform_game_id=s.platform_game_id AND platform_achievement_id=s.platform_achievement_id;
END $$;
SET LOCAL ROLE authenticated;
DO $$ DECLARE b jsonb; BEGIN
 b:=public.discover_my_platinum_celebration();ASSERT (b->>'count')::integer=1;ASSERT NOT (b->>'historical')::boolean;
 ASSERT public.acknowledge_my_platinum_celebration((b->>'id')::uuid);
END $$;
SET LOCAL ROLE postgres;
DO $$ DECLARE v_user uuid:=gen_random_uuid(); BEGIN
 INSERT INTO auth.users(id,email,created_at,updated_at) VALUES(v_user,'platinum-art-'||v_user::text||'@example.invalid',now(),now());
 ASSERT public.reserve_platinum_art(v_user,gen_random_uuid(),repeat('c',64),2,'not-owned')->>'state'='premium_required';
 INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_expires_at) VALUES(v_user,true,'test_platinum',now()-interval '1 hour');
 ASSERT public.reserve_platinum_art(v_user,gen_random_uuid(),repeat('c',64),2,'not-owned')->>'state'='premium_required','Expired Premium cannot generate';
END $$;
-- The service-only reservation verifies Premium, ownership, request replay and
-- allowance atomically; neither credit packs nor client Premium flags help.
DO $$ DECLARE v_user uuid:=current_setting('platinum.test.owner')::uuid; c record; r jsonb; id uuid; BEGIN
 SELECT * INTO c FROM statusxp_private.platinum_card_facts(v_user) LIMIT 1;
 INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_expires_at)
 VALUES(v_user,true,'test_platinum',now()+interval '1 day') ON CONFLICT(user_id) DO UPDATE SET is_premium=true,premium_source='test_platinum',premium_expires_at=now()+interval '1 day';
 r:=public.reserve_platinum_art(v_user,'00000000-0000-4000-8000-000000000001',repeat('a',64),4,c.platform_game_id);ASSERT r->>'state'='not_owned';
 FOR i IN 1..3 LOOP
  id:=('00000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid;
  r:=public.reserve_platinum_art(v_user,id,repeat('a',64),c.platform_id,c.platform_game_id);ASSERT r->>'state'='reserved';
  ASSERT public.reserve_platinum_art(v_user,id,repeat('a',64),c.platform_id,c.platform_game_id)->>'state'='pending';
  ASSERT public.reserve_platinum_art(v_user,id,repeat('b',64),c.platform_id,c.platform_game_id)->>'state'='conflict';
  ASSERT public.finish_platinum_art(v_user,id,v_user::text||'/'||id::text||'.png');
  ASSERT public.reserve_platinum_art(v_user,id,repeat('a',64),c.platform_id,c.platform_game_id)->>'state'='succeeded';
 END LOOP;
 ASSERT public.reserve_platinum_art(v_user,'00000000-0000-4000-8000-000000000004',repeat('a',64),c.platform_id,c.platform_game_id)->>'state'='limit_reached';
 DELETE FROM statusxp_private.platinum_art_requests WHERE user_id=v_user;
 r:=public.reserve_platinum_art(v_user,'00000000-0000-4000-8000-000000000005',repeat('a',64),c.platform_id,c.platform_game_id);
 ASSERT r->>'state'='reserved';
 ASSERT public.finish_platinum_art(v_user,'00000000-0000-4000-8000-000000000005',NULL);
 ASSERT public.reserve_platinum_art(v_user,'00000000-0000-4000-8000-000000000006',repeat('a',64),c.platform_id,c.platform_game_id)->>'state'='reserved';
END $$;
ROLLBACK;
