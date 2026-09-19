-- Permanent application access is independent of all billing providers.
BEGIN;
CREATE TABLE IF NOT EXISTS public.app_access_grants (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('owner','admin','developer')),
  premium boolean NOT NULL DEFAULT true,
  granted_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);
ALTER TABLE public.app_access_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_access_grants FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_access_grants TO service_role;

CREATE OR REPLACE FUNCTION public.has_app_admin_access(p_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT EXISTS(SELECT 1 FROM public.app_access_grants
    WHERE user_id=p_user_id AND role IN ('owner','admin') AND revoked_at IS NULL);
$$;
REVOKE ALL ON FUNCTION public.has_app_admin_access(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.has_app_admin_access(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.get_my_app_access()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
  SELECT coalesce((SELECT jsonb_build_object('role',role,'premium',premium)
    FROM public.app_access_grants WHERE user_id=auth.uid() AND revoked_at IS NULL),
    jsonb_build_object('role',NULL,'premium',false));
$$;
REVOKE ALL ON FUNCTION public.get_my_app_access() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_app_access() TO authenticated,service_role;

-- Existing web/mobile clients still read this projection. Old billing writers
-- cannot replace the independent owner's permanent grant with an expiry.
CREATE OR REPLACE FUNCTION public.preserve_app_premium_grant()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE granted timestamptz;
BEGIN
  SELECT granted_at INTO granted FROM public.app_access_grants
    WHERE user_id=NEW.user_id AND premium AND revoked_at IS NULL;
  IF FOUND THEN
    NEW.is_premium:=true;
    NEW.premium_source:='developer';
    NEW.premium_expires_at:=NULL;
    NEW.premium_since:=coalesce(NEW.premium_since,granted);
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.preserve_app_premium_grant() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS preserve_app_premium_grant ON public.user_premium_status;
CREATE TRIGGER preserve_app_premium_grant BEFORE INSERT OR UPDATE ON public.user_premium_status
  FOR EACH ROW EXECUTE FUNCTION public.preserve_app_premium_grant();
-- Existing changelog administration accepts real owner/admin accounts.
DO $policy$
BEGIN
  IF to_regclass('public.app_updates') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "App administrators manage updates" ON public.app_updates';
    EXECUTE 'CREATE POLICY "App administrators manage updates" ON public.app_updates FOR ALL TO authenticated USING ((public.get_my_app_access()->>''role'') IN (''owner'',''admin'')) WITH CHECK ((public.get_my_app_access()->>''role'') IN (''owner'',''admin''))';
    GRANT SELECT,INSERT,UPDATE,DELETE ON public.app_updates TO authenticated;
    -- Its identity sequence is used by inserts from the administrative client.
    IF pg_get_serial_sequence('public.app_updates','id') IS NOT NULL THEN
      EXECUTE format('GRANT USAGE ON SEQUENCE %s TO authenticated',pg_get_serial_sequence('public.app_updates','id'));
    END IF;
  END IF;
END;
$policy$;
COMMIT;
