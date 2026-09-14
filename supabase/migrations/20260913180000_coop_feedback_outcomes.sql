BEGIN;
CREATE TABLE IF NOT EXISTS public.coop_session_feedback (
 request_id uuid NOT NULL REFERENCES public.trophy_help_requests(id) ON DELETE CASCADE,
 user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 outcome text NOT NULL CHECK(outcome IN ('goal_completed','made_progress','did_not_play')),
 team_again boolean,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(request_id,user_id)
);
ALTER TABLE public.coop_session_feedback ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.coop_session_feedback FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.coop_session_feedback TO authenticated;
GRANT ALL ON public.coop_session_feedback TO service_role;
DROP POLICY IF EXISTS "Read own co-op feedback" ON public.coop_session_feedback;
CREATE POLICY "Read own co-op feedback" ON public.coop_session_feedback FOR SELECT TO authenticated USING(user_id=auth.uid());

CREATE OR REPLACE FUNCTION public.save_coop_feedback(p_request_id uuid, p_outcome text, p_team_again boolean DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE r public.trophy_help_requests; caller uuid:=auth.uid();
BEGIN
 SELECT * INTO r FROM public.trophy_help_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND OR caller IS NULL OR r.status <> 'completed' OR NOT (
   r.profile_id=caller OR EXISTS(SELECT 1 FROM public.trophy_help_responses
     WHERE request_id=p_request_id AND helper_profile_id=caller AND status IN ('accepted','completed'))
 ) THEN RAISE EXCEPTION 'Only participants can leave feedback after completion' USING ERRCODE='42501'; END IF;
 IF p_outcome IS NULL OR p_outcome NOT IN ('goal_completed','made_progress','did_not_play') THEN
   RAISE EXCEPTION 'Choose a valid session outcome' USING ERRCODE='22023';
 END IF;
 INSERT INTO public.coop_session_feedback(request_id,user_id,outcome,team_again)
 VALUES(p_request_id,caller,p_outcome,p_team_again)
 ON CONFLICT(request_id,user_id) DO UPDATE SET outcome=excluded.outcome,team_again=excluded.team_again,updated_at=now();
END $$;
REVOKE ALL ON FUNCTION public.save_coop_feedback(uuid,text,boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_coop_feedback(uuid,text,boolean) TO authenticated;

-- Server-only lifecycle observations. Historical event times remain unknown.
CREATE TABLE IF NOT EXISTS public.coop_request_outcomes (
 request_id uuid PRIMARY KEY REFERENCES public.trophy_help_requests(id) ON DELETE CASCADE,
 observed_at timestamptz NOT NULL DEFAULT now(),
 request_status text NOT NULL,
 first_accepted_at timestamptz,
 finished_at timestamptz
);
ALTER TABLE public.coop_request_outcomes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.coop_request_outcomes FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.coop_request_outcomes TO service_role;
INSERT INTO public.coop_request_outcomes(request_id,request_status)
 SELECT id,status FROM public.trophy_help_requests ON CONFLICT(request_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.record_coop_request_outcome()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF TG_OP='UPDATE' AND OLD.status IS NOT DISTINCT FROM NEW.status THEN RETURN NEW; END IF;
 INSERT INTO public.coop_request_outcomes(request_id,request_status,finished_at)
 VALUES(NEW.id,NEW.status,CASE WHEN NEW.status IN ('completed','closed','cancelled') THEN now() END)
 ON CONFLICT(request_id) DO UPDATE SET request_status=excluded.request_status,
 finished_at=coalesce(public.coop_request_outcomes.finished_at,excluded.finished_at);
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION public.record_coop_first_acceptance()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
 IF NEW.status <> 'accepted' THEN RETURN NEW; END IF;
 INSERT INTO public.coop_request_outcomes(request_id,request_status,first_accepted_at)
 SELECT NEW.request_id,status,now() FROM public.trophy_help_requests WHERE id=NEW.request_id
 ON CONFLICT(request_id) DO UPDATE SET first_accepted_at=coalesce(public.coop_request_outcomes.first_accepted_at,excluded.first_accepted_at);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.record_coop_request_outcome(), public.record_coop_first_acceptance() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS record_coop_request_outcome ON public.trophy_help_requests;
CREATE TRIGGER record_coop_request_outcome AFTER INSERT OR UPDATE OF status ON public.trophy_help_requests
 FOR EACH ROW EXECUTE FUNCTION public.record_coop_request_outcome();
DROP TRIGGER IF EXISTS record_coop_first_acceptance ON public.trophy_help_responses;
CREATE TRIGGER record_coop_first_acceptance AFTER INSERT OR UPDATE OF status ON public.trophy_help_responses
 FOR EACH ROW EXECUTE FUNCTION public.record_coop_first_acceptance();
COMMIT;
