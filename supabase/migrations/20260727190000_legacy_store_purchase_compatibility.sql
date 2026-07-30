-- Temporary compatibility for installed app versions that predate the
-- verify-store-purchase Edge Function. Remove these grants and policies after
-- version 1.1.17+92 has been rolled out and legacy purchase traffic has ended.
-- Anonymous access intentionally remains revoked.

CREATE POLICY "Legacy clients can insert their own premium status"
  ON public.user_premium_status
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "Legacy clients can update their own premium status"
  ON public.user_premium_status
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

GRANT INSERT, UPDATE ON public.user_premium_status TO authenticated;

GRANT EXECUTE ON FUNCTION public.add_ai_pack_credits(
  uuid, character varying, integer, numeric, character varying
) TO authenticated;
