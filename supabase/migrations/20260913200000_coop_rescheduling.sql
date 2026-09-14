BEGIN;
ALTER TABLE public.trophy_help_requests
 ADD COLUMN IF NOT EXISTS schedule_revision integer NOT NULL DEFAULT 0,
 ADD COLUMN IF NOT EXISTS schedule_changed_at timestamptz;

CREATE OR REPLACE FUNCTION public.initialize_coop_confirmation()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
 NEW.last_confirmed_at := NULL;
 NEW.schedule_revision := 0;
 NEW.schedule_changed_at := NULL;
 RETURN NEW;
END $$;

CREATE OR REPLACE FUNCTION public.record_coop_schedule_change()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
 IF NEW.scheduled_at IS DISTINCT FROM OLD.scheduled_at
 OR NEW.session_utc_offset_minutes IS DISTINCT FROM OLD.session_utc_offset_minutes THEN
  NEW.schedule_revision := OLD.schedule_revision + 1;
  NEW.schedule_changed_at := now();
 ELSE
  NEW.schedule_revision := OLD.schedule_revision;
  NEW.schedule_changed_at := OLD.schedule_changed_at;
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS record_coop_schedule_change ON public.trophy_help_requests;
CREATE TRIGGER record_coop_schedule_change BEFORE UPDATE ON public.trophy_help_requests
FOR EACH ROW EXECUTE FUNCTION public.record_coop_schedule_change();

CREATE OR REPLACE FUNCTION public.reschedule_coop_request(
 p_request_id uuid, p_scheduled_at timestamptz,
 p_utc_offset_minutes integer, p_expected_revision integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.trophy_help_requests;
BEGIN
 SELECT * INTO r FROM public.trophy_help_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND OR auth.uid() IS NULL OR r.profile_id IS DISTINCT FROM auth.uid() THEN
  RAISE EXCEPTION 'Only the owner can change session timing' USING ERRCODE='42501';
 END IF;
 IF r.status NOT IN ('open','assigned','matched') THEN
  RAISE EXCEPTION 'This request is no longer active' USING ERRCODE='22023';
 END IF;
 IF (p_scheduled_at IS NULL) <> (p_utc_offset_minutes IS NULL)
 OR p_scheduled_at <= now() OR p_utc_offset_minutes NOT BETWEEN -840 AND 840 THEN
  RAISE EXCEPTION 'Choose a future time with its UTC offset, or flexible timing' USING ERRCODE='22023';
 END IF;
 -- A repeated successful save is harmless, even if its revision is now old.
 IF r.scheduled_at IS NOT DISTINCT FROM p_scheduled_at
 AND r.session_utc_offset_minutes IS NOT DISTINCT FROM p_utc_offset_minutes THEN RETURN; END IF;
 IF p_expected_revision IS DISTINCT FROM r.schedule_revision THEN
  RAISE EXCEPTION 'Session timing changed. Reload before saving.' USING ERRCODE='40001';
 END IF;
 UPDATE public.trophy_help_requests SET scheduled_at=p_scheduled_at,
 session_utc_offset_minutes=p_utc_offset_minutes
 WHERE id=p_request_id;
END $$;
REVOKE ALL ON FUNCTION public.reschedule_coop_request(uuid,timestamptz,integer,integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reschedule_coop_request(uuid,timestamptz,integer,integer) TO authenticated;
COMMIT;
