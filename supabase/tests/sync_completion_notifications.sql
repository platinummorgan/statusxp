BEGIN;
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009961','sync-notify-9961@statusxp.invalid','{"display_name":"Sync fixture"}'),
 ('00000000-0000-4000-8000-000000009962','sync-notify-9962@statusxp.invalid','{"display_name":"Other fixture"}');
UPDATE public.profiles_private SET psn_sync_status='syncing' WHERE id='00000000-0000-4000-8000-000000009961';
UPDATE public.profiles_private SET psn_sync_status='success',last_psn_sync_at=now() WHERE id='00000000-0000-4000-8000-000000009961';
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-000000009961"}',true);
DO $$ BEGIN
 ASSERT (SELECT count(*)=1 FROM public.profile_sync_notifications),'Owner only sees their status';
 ASSERT (SELECT psn_sync_status='success' AND last_psn_sync_at=now() FROM public.profile_sync_notifications),'Completion and timestamp publish atomically';
 ASSERT NOT has_table_privilege('authenticated','public.profile_sync_notifications','UPDATE'),'Clients cannot forge sync notifications';
 ASSERT NOT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profile_sync_notifications' AND column_name LIKE '%token%'),'Notification data has no credentials';
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{}',true);
DO $$ BEGIN ASSERT EXISTS(SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND tablename='profile_sync_notifications'),'Sync notifications are published to Realtime'; END $$;
SELECT 'Sync completion publication and ownership assertions passed' result;
ROLLBACK;
