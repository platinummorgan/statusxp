-- A scalar JSON snapshot preserves the full history past PostgREST's row cap.
-- Delegate all public/private/owner authorization to the existing guarded RPC.
BEGIN;
CREATE OR REPLACE FUNCTION public.get_public_user_grouped_games_snapshot(p_target_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER
SET search_path='public','pg_temp' AS $$
 SELECT coalesce(jsonb_agg(to_jsonb(g)),'[]'::jsonb)
 FROM public.get_public_user_grouped_games(p_target_user_id) g;
$$;
REVOKE ALL ON FUNCTION public.get_public_user_grouped_games_snapshot(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_user_grouped_games_snapshot(uuid) TO anon,authenticated,service_role;
NOTIFY pgrst,'reload schema';
COMMIT;
