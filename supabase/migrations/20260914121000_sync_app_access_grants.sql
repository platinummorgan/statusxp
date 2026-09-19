-- Grant creation/revocation must update the compatibility projection as well.
BEGIN;
CREATE OR REPLACE FUNCTION public.sync_app_premium_grant()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u uuid; granted timestamptz;
BEGIN
  IF TG_OP='DELETE' THEN u:=OLD.user_id; ELSE u:=NEW.user_id; END IF;
  SELECT granted_at INTO granted FROM public.app_access_grants
    WHERE user_id=u AND premium AND revoked_at IS NULL;
  IF FOUND THEN
    INSERT INTO public.user_premium_status(user_id,is_premium,premium_source,premium_since,premium_expires_at,updated_at)
      VALUES(u,true,'developer',granted,NULL,now())
      ON CONFLICT(user_id) DO UPDATE SET is_premium=true,premium_source='developer',premium_expires_at=NULL,updated_at=now();
  ELSE
    -- Paid source records remain independent and are evaluated by the shared
    -- entitlement reader; do not revoke a projection belonging to a provider.
    UPDATE public.user_premium_status SET is_premium=false,premium_source=NULL,premium_expires_at=now(),updated_at=now()
      WHERE user_id=u AND premium_source='developer';
  END IF;
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.sync_app_premium_grant() FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS sync_app_premium_grant ON public.app_access_grants;
CREATE TRIGGER sync_app_premium_grant AFTER INSERT OR UPDATE OR DELETE ON public.app_access_grants
  FOR EACH ROW EXECUTE FUNCTION public.sync_app_premium_grant();
COMMIT;
