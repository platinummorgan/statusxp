BEGIN;
INSERT INTO auth.users(id,email,created_at,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009954','profile-9954@statusxp.invalid','2026-01-01T00:00:00Z','{"display_name":"Profile repair fixture 9954"}'),
 ('00000000-0000-4000-8000-000000009955','profile-9955@statusxp.invalid',now(),'{"display_name":"Profile repair fixture 9954"}'),
 ('00000000-0000-4000-8000-000000009956',NULL,now(),'{}');
DO $$ BEGIN
 ASSERT (SELECT count(*)=3 FROM profiles_private WHERE id IN('00000000-0000-4000-8000-000000009954','00000000-0000-4000-8000-000000009955','00000000-0000-4000-8000-000000009956')),'All signups must create profiles';
 ASSERT (SELECT count(DISTINCT username)=3 FROM profiles_private WHERE id IN('00000000-0000-4000-8000-000000009954','00000000-0000-4000-8000-000000009955','00000000-0000-4000-8000-000000009956')),'Name collisions must not reject signup';
 ASSERT (SELECT username='Profile repair fixture 9954' AND created_at='2026-01-01T00:00:00Z'::timestamptz FROM profiles_private WHERE id='00000000-0000-4000-8000-000000009954');
 ASSERT NOT statusxp_private.ensure_auth_profile('00000000-0000-4000-8000-000000009954'),'Existing profile must not be rewritten';
 ASSERT (SELECT count(*)=3 FROM profile_sync_notifications WHERE user_id IN('00000000-0000-4000-8000-000000009954','00000000-0000-4000-8000-000000009955','00000000-0000-4000-8000-000000009956')),'Profile side effects must run';
 ASSERT NOT has_function_privilege('anon','statusxp_private.ensure_auth_profile(uuid)','EXECUTE');
 ASSERT NOT has_function_privilege('authenticated','statusxp_private.ensure_auth_profile(uuid)','EXECUTE');
END $$;
-- Restore only missing data; deleted auth accounts remain deleted.
DELETE FROM profiles_private WHERE id='00000000-0000-4000-8000-000000009955';
SELECT statusxp_private.ensure_auth_profile('00000000-0000-4000-8000-000000009955');
UPDATE auth.users SET deleted_at=now() WHERE id='00000000-0000-4000-8000-000000009956';
DELETE FROM profiles_private WHERE id='00000000-0000-4000-8000-000000009956';
DO $$ BEGIN
 ASSERT NOT statusxp_private.ensure_auth_profile('00000000-0000-4000-8000-000000009956');
 ASSERT NOT EXISTS(SELECT 1 FROM profiles_private WHERE id='00000000-0000-4000-8000-000000009956');
 ASSERT (SELECT psn_sync_status='never_synced' AND xbox_sync_status='never_synced' AND steam_sync_status='never_synced' AND subscription_tier='free' AND last_psn_sync_at IS NULL AND last_xbox_sync_at IS NULL AND last_steam_sync_at IS NULL FROM profiles_private WHERE id='00000000-0000-4000-8000-000000009955');
 ASSERT NOT EXISTS(SELECT 1 FROM leaderboard_cache WHERE user_id IN('00000000-0000-4000-8000-000000009954','00000000-0000-4000-8000-000000009955'));
END $$;
ROLLBACK;
