BEGIN;
ALTER TABLE public.trophy_help_requests
  ADD COLUMN IF NOT EXISTS scheduled_at timestamptz,
  ADD COLUMN IF NOT EXISTS session_utc_offset_minutes smallint,
  ADD COLUMN IF NOT EXISTS helpers_needed smallint NOT NULL DEFAULT 1;
ALTER TABLE public.trophy_help_requests DROP CONSTRAINT IF EXISTS trophy_help_requests_status_check;
ALTER TABLE public.trophy_help_requests ADD CONSTRAINT trophy_help_requests_status_check
  CHECK (status IN ('open','assigned','matched','completed','closed','cancelled'));
ALTER TABLE public.trophy_help_requests DROP CONSTRAINT IF EXISTS coop_session_fields_check;
ALTER TABLE public.trophy_help_requests ADD CONSTRAINT coop_session_fields_check CHECK (
  helpers_needed BETWEEN 1 AND 7
  AND ((scheduled_at IS NULL AND session_utc_offset_minutes IS NULL)
    OR (scheduled_at IS NOT NULL AND session_utc_offset_minutes IS NOT NULL
      AND session_utc_offset_minutes BETWEEN -840 AND 840))
);
CREATE INDEX IF NOT EXISTS coop_response_request_helper ON public.trophy_help_responses(request_id, helper_profile_id);

-- Preserve historical duplicate rows; serialize and reject all new duplicates.
CREATE OR REPLACE FUNCTION public.guard_coop_offer_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE request_row public.trophy_help_requests;
BEGIN
  SELECT * INTO request_row FROM public.trophy_help_requests WHERE id = NEW.request_id FOR UPDATE;
  IF NOT FOUND OR auth.uid() IS NULL OR NEW.helper_profile_id <> auth.uid()
    OR NEW.helper_user_id <> auth.uid() OR NEW.status <> 'pending'
    OR request_row.profile_id = auth.uid() OR request_row.status <> 'open' THEN
    RAISE EXCEPTION 'This request is not accepting your offer' USING ERRCODE = '42501';
  END IF;
  IF EXISTS (SELECT 1 FROM public.trophy_help_responses
    WHERE request_id = NEW.request_id AND helper_profile_id = NEW.helper_profile_id) THEN
    RAISE EXCEPTION 'You already offered help on this request' USING ERRCODE = '23505';
  END IF;
  RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_coop_offer_insert() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS guard_coop_offer_insert ON public.trophy_help_responses;
CREATE TRIGGER guard_coop_offer_insert BEFORE INSERT ON public.trophy_help_responses
FOR EACH ROW EXECUTE FUNCTION public.guard_coop_offer_insert();

CREATE OR REPLACE FUNCTION public.guard_coop_session_insert()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NEW.scheduled_at IS NOT NULL AND NEW.scheduled_at <= now() THEN
    RAISE EXCEPTION 'Choose a future session time' USING ERRCODE = '22023';
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS guard_coop_session_insert ON public.trophy_help_requests;
CREATE TRIGGER guard_coop_session_insert BEFORE INSERT ON public.trophy_help_requests
FOR EACH ROW EXECUTE FUNCTION public.guard_coop_session_insert();

-- State changes go through owner-checked RPCs, never two independent writes.
REVOKE UPDATE ON public.trophy_help_requests, public.trophy_help_responses FROM PUBLIC, anon, authenticated;
DROP POLICY IF EXISTS "Users can create trophy help requests" ON public.trophy_help_requests;
CREATE POLICY "Users can create trophy help requests" ON public.trophy_help_requests
FOR INSERT TO authenticated WITH CHECK (profile_id = auth.uid() AND user_id = auth.uid() AND status = 'open');

CREATE OR REPLACE FUNCTION public.accept_coop_offer(p_response_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE req_id uuid; request_row public.trophy_help_requests; response_row public.trophy_help_responses; accepted_count integer;
BEGIN
  SELECT request_id INTO req_id FROM public.trophy_help_responses WHERE id = p_response_id;
  SELECT * INTO request_row FROM public.trophy_help_requests WHERE id = req_id FOR UPDATE;
  IF NOT FOUND OR auth.uid() IS NULL OR request_row.profile_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the request owner can accept an offer' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO response_row FROM public.trophy_help_responses WHERE id = p_response_id FOR UPDATE;
  IF response_row.status IN ('accepted','completed') THEN RETURN; END IF;
  IF request_row.status <> 'open' OR response_row.status <> 'pending' THEN
    RAISE EXCEPTION 'This offer is no longer available' USING ERRCODE = '22023';
  END IF;
  SELECT count(DISTINCT helper_profile_id) INTO accepted_count FROM public.trophy_help_responses
    WHERE request_id = req_id AND status = 'accepted';
  IF accepted_count >= request_row.helpers_needed OR EXISTS (
    SELECT 1 FROM public.trophy_help_responses WHERE request_id = req_id
    AND helper_profile_id = response_row.helper_profile_id AND status = 'accepted'
  ) THEN RAISE EXCEPTION 'The player or session is already confirmed' USING ERRCODE = '22023'; END IF;
  UPDATE public.trophy_help_responses SET status = 'accepted' WHERE id = p_response_id;
  IF accepted_count + 1 >= request_row.helpers_needed THEN
    UPDATE public.trophy_help_requests SET status = 'assigned' WHERE id = req_id;
    UPDATE public.trophy_help_responses SET status = 'declined' WHERE request_id = req_id AND status = 'pending';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.decline_coop_offer(p_response_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE req_id uuid; owner_id uuid; response_status text;
BEGIN
  SELECT request_id INTO req_id FROM public.trophy_help_responses WHERE id = p_response_id;
  SELECT profile_id INTO owner_id FROM public.trophy_help_requests WHERE id = req_id FOR UPDATE;
  IF NOT FOUND OR auth.uid() IS NULL OR owner_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the request owner can decline an offer' USING ERRCODE = '42501';
  END IF;
  SELECT status INTO response_status FROM public.trophy_help_responses WHERE id = p_response_id;
  IF response_status = 'declined' THEN RETURN; END IF;
  IF response_status <> 'pending' THEN RAISE EXCEPTION 'Only pending offers can be declined' USING ERRCODE = '22023'; END IF;
  UPDATE public.trophy_help_responses SET status = 'declined' WHERE id = p_response_id;
END $$;

CREATE OR REPLACE FUNCTION public.finish_coop_request(p_request_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE request_row public.trophy_help_requests;
BEGIN
  SELECT * INTO request_row FROM public.trophy_help_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR auth.uid() IS NULL OR request_row.profile_id <> auth.uid() THEN
    RAISE EXCEPTION 'Only the request owner can finish this request' USING ERRCODE = '42501';
  END IF;
  IF p_status NOT IN ('completed','cancelled','closed') OR p_status IS NULL THEN
    RAISE EXCEPTION 'Invalid final request status' USING ERRCODE = '22023';
  END IF;
  IF request_row.status = p_status THEN RETURN; END IF;
  IF request_row.status NOT IN ('open','assigned','matched') THEN
    RAISE EXCEPTION 'This request has already ended' USING ERRCODE = '22023';
  END IF;
  UPDATE public.trophy_help_requests SET status = p_status WHERE id = p_request_id;
  UPDATE public.trophy_help_responses SET status = CASE
    WHEN status = 'accepted' AND p_status = 'completed' THEN 'completed' ELSE 'declined' END
    WHERE request_id = p_request_id AND status IN ('accepted','pending');
END $$;
REVOKE ALL ON FUNCTION public.accept_coop_offer(uuid), public.decline_coop_offer(uuid), public.finish_coop_request(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_coop_offer(uuid), public.decline_coop_offer(uuid), public.finish_coop_request(uuid,text) TO authenticated;
COMMIT;
