-- Background sync refreshes exceed authenticator's inherited 8s timeout.
-- Keep public/client role limits intact and bound server work to one minute.
-- Apply this migration directly; do not push unrelated pending migrations.
BEGIN;
ALTER ROLE service_role SET statement_timeout = '60s';
NOTIFY pgrst, 'reload config';
COMMIT;
