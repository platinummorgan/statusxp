-- Public source excludes the one-time account-specific recovery data.
-- The original reviewed operation is retained in the private local audit archive.
-- Reviewed active auth accounts from missing-profiles-before.json. Restore
-- minimal profiles only; platform links, credentials and scores are not inferred.
BEGIN;
SET LOCAL lock_timeout='10s';
DO $$ DECLARE target uuid; BEGIN
 FOR target IN
 SELECT u.id FROM (SELECT NULL::uuid AS id WHERE false) reviewed JOIN auth.users u USING(id)
 LEFT JOIN public.profiles_private p ON p.id=u.id
 WHERE p.id IS NULL AND u.deleted_at IS NULL AND NOT coalesce(u.is_anonymous,false)
 AND (u.banned_until IS NULL OR u.banned_until<now())
 AND EXISTS(SELECT 1 FROM auth.identities i WHERE i.user_id=u.id)
 ORDER BY u.id
 LOOP
  PERFORM statusxp_private.ensure_auth_profile(target);
 END LOOP;
END $$;
COMMIT;
