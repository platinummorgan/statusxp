BEGIN;
ALTER TABLE public.trophy_help_requests ADD COLUMN IF NOT EXISTS last_confirmed_at timestamptz;

-- Confirmation time is server-owned; new posts must not forge a confirmation.
CREATE OR REPLACE FUNCTION public.initialize_coop_confirmation()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN NEW.last_confirmed_at := NULL; RETURN NEW; END $$;
DROP TRIGGER IF EXISTS initialize_coop_confirmation ON public.trophy_help_requests;
CREATE TRIGGER initialize_coop_confirmation BEFORE INSERT ON public.trophy_help_requests
FOR EACH ROW EXECUTE FUNCTION public.initialize_coop_confirmation();

CREATE OR REPLACE FUNCTION public.reconfirm_coop_request(p_request_id uuid, p_clear_past_schedule boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.trophy_help_requests;
BEGIN
 SELECT * INTO r FROM public.trophy_help_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND OR auth.uid() IS NULL OR r.profile_id <> auth.uid() THEN
   RAISE EXCEPTION 'Only the owner can confirm this request' USING ERRCODE='42501';
 END IF;
 IF r.status <> 'open' THEN
   RAISE EXCEPTION 'Only open requests can be reconfirmed' USING ERRCODE='22023';
 END IF;
 IF r.scheduled_at <= now() AND NOT coalesce(p_clear_past_schedule,false) THEN
   RAISE EXCEPTION 'The scheduled time has passed; confirm flexible timing or finish the request' USING ERRCODE='22023';
 END IF;
 UPDATE public.trophy_help_requests SET
   last_confirmed_at=now(),
   scheduled_at=CASE WHEN r.scheduled_at <= now() AND p_clear_past_schedule THEN NULL ELSE r.scheduled_at END,
   session_utc_offset_minutes=CASE WHEN r.scheduled_at <= now() AND p_clear_past_schedule THEN NULL ELSE r.session_utc_offset_minutes END
 WHERE id=p_request_id;
END $$;
REVOKE ALL ON FUNCTION public.reconfirm_coop_request(uuid,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reconfirm_coop_request(uuid,boolean) TO authenticated;
COMMIT;
