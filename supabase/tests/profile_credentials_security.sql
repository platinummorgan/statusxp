BEGIN;

-- Synthetic records only; the enclosing transaction is always rolled back.
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009901','profile-security-9901@statusxp.invalid','{"display_name":"Security fixture one"}'),
 ('00000000-0000-4000-8000-000000009902','profile-security-9902@statusxp.invalid','{"display_name":"Security fixture two"}');
UPDATE public.profiles_private SET psn_account_id='synthetic-psn',psn_online_id='SyntheticPSN',
 psn_npsso_token='synthetic-npsso',psn_access_token='synthetic-psn-access',psn_refresh_token='synthetic-psn-refresh',
 xbox_xuid='synthetic-xuid',xbox_gamertag='SyntheticXbox',xbox_access_token='synthetic-xbox-access',xbox_refresh_token='synthetic-xbox-refresh',
 xbox_user_hash='synthetic-hash',xbox_profile_gamerscore=1234,
 steam_id='76561199999990001',steam_api_key=repeat('a',32),steam_display_name='SyntheticSteam',
 psn_sync_status='success',xbox_sync_status='success',steam_sync_status='success'
 WHERE id='00000000-0000-4000-8000-000000009901';
SET LOCAL ROLE anon;
SELECT set_config('request.jwt.claims','{"role":"anon"}',true);
DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM public.profiles WHERE psn_npsso_token IS NOT NULL OR psn_access_token IS NOT NULL OR psn_refresh_token IS NOT NULL OR xbox_access_token IS NOT NULL OR xbox_refresh_token IS NOT NULL OR steam_api_key IS NOT NULL OR xbox_user_hash IS NOT NULL),'Anonymous credentials must be masked';
 ASSERT EXISTS(SELECT 1 FROM public.profiles WHERE id='00000000-0000-4000-8000-000000009901' AND psn_online_id='SyntheticPSN'),'Safe public profile fields remain readable';
 BEGIN PERFORM id FROM public.profiles_private LIMIT 1; RAISE EXCEPTION 'Private table readable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SET LOCAL ROLE postgres;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000009901"}',true);
DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM public.profiles WHERE psn_access_token IS NOT NULL OR xbox_access_token IS NOT NULL OR steam_api_key IS NOT NULL),'Authenticated clients must not receive credentials, including their own';
 BEGIN PERFORM id FROM public.profiles_private LIMIT 1; RAISE EXCEPTION 'Private table readable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.profiles SET preferred_display_platform='xbox',show_on_leaderboard=false WHERE id='00000000-0000-4000-8000-000000009901';
 ASSERT (SELECT preferred_display_platform='xbox' AND NOT show_on_leaderboard FROM public.profiles WHERE id='00000000-0000-4000-8000-000000009901'),'Own settings remain editable';
 BEGIN UPDATE public.profiles SET xbox_profile_gamerscore=999999 WHERE id='00000000-0000-4000-8000-000000009901'; RAISE EXCEPTION 'Trusted score editable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.profiles SET subscription_tier='premium' WHERE id='00000000-0000-4000-8000-000000009901'; RAISE EXCEPTION 'Subscription editable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.profiles SET last_psn_sync_at=now() WHERE id='00000000-0000-4000-8000-000000009901'; RAISE EXCEPTION 'Sync timestamp editable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.profiles SET psn_access_token='forged' WHERE id='00000000-0000-4000-8000-000000009901'; RAISE EXCEPTION 'Token editable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 BEGIN UPDATE public.profiles SET username='forged' WHERE id='00000000-0000-4000-8000-000000009902'; RAISE EXCEPTION 'Other profile editable'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
 UPDATE public.profiles SET steam_id='76561199999990001',steam_api_key=repeat('b',32) WHERE id='00000000-0000-4000-8000-000000009901';
 ASSERT (SELECT steam_api_key IS NULL FROM public.profiles WHERE id='00000000-0000-4000-8000-000000009901'),'Steam key remains write-only';
 UPDATE public.profiles SET psn_account_id=NULL,psn_online_id=NULL,psn_npsso_token=NULL,psn_access_token=NULL,psn_refresh_token=NULL,psn_token_expires_at=NULL,psn_sync_status='never_synced' WHERE id='00000000-0000-4000-8000-000000009901';
 UPDATE public.profiles SET xbox_xuid=NULL,xbox_gamertag=NULL,xbox_access_token=NULL,xbox_refresh_token=NULL,xbox_token_expires_at=NULL,xbox_sync_status='never_synced' WHERE id='00000000-0000-4000-8000-000000009901';
 UPDATE public.profiles SET steam_id=NULL,steam_api_key=NULL,steam_sync_status='never_synced' WHERE id='00000000-0000-4000-8000-000000009901';
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{}',true);
DO $$ BEGIN
 ASSERT (SELECT psn_access_token IS NULL AND psn_refresh_token IS NULL AND psn_npsso_token IS NULL AND xbox_access_token IS NULL AND xbox_refresh_token IS NULL AND xbox_user_hash IS NULL AND steam_api_key IS NULL AND steam_display_name IS NULL AND xbox_profile_gamerscore=1234 FROM public.profiles_private WHERE id='00000000-0000-4000-8000-000000009901'),'Disconnects clear credentials without allowing score edits';
END $$;
SET LOCAL ROLE service_role;
SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
UPDATE public.profiles SET xbox_profile_gamerscore=4321,psn_access_token='synthetic-service-token' WHERE id='00000000-0000-4000-8000-000000009901';
DO $$ BEGIN
 ASSERT (SELECT psn_access_token='synthetic-service-token' AND xbox_profile_gamerscore=4321 FROM public.profiles WHERE id='00000000-0000-4000-8000-000000009901'),'Service credential reads and trusted writes remain supported';
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{}',true);
SELECT 'Profile security and compatibility assertions passed' result;
ROLLBACK;
