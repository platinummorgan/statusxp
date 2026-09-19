-- Keep a helper's request history readable after a request leaves the open feed.
-- Definer lookup avoids recursion through the response table's owner policy.
BEGIN;

CREATE OR REPLACE FUNCTION public.has_own_coop_offer(p_request_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.trophy_help_responses r
    WHERE r.request_id = p_request_id AND r.helper_profile_id = auth.uid()
  );
$$;
REVOKE ALL ON FUNCTION public.has_own_coop_offer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_own_coop_offer(uuid) TO authenticated;

DROP POLICY IF EXISTS "Helpers can revisit their co-op requests" ON public.trophy_help_requests;
CREATE POLICY "Helpers can revisit their co-op requests"
ON public.trophy_help_requests FOR SELECT TO authenticated
USING (public.has_own_coop_offer(id));

-- A new offer must belong to its sender and target someone else's open request.
-- This also prevents creating an offer to gain access to a private closed post.
DROP POLICY IF EXISTS "Users can create trophy help responses" ON public.trophy_help_responses;
CREATE POLICY "Users can create trophy help responses"
ON public.trophy_help_responses FOR INSERT TO authenticated
WITH CHECK (
  helper_profile_id = auth.uid()
  AND helper_user_id = auth.uid()
  AND status = 'pending'
  AND EXISTS (
    SELECT 1 FROM public.trophy_help_requests r
    WHERE r.id = request_id AND r.status = 'open' AND r.profile_id <> auth.uid()
  )
);

COMMIT;
