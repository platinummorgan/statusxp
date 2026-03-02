-- Public read-only game history RPC for leaderboard-visible users.
-- Reuses get_user_grouped_games shape so app UI can render with existing models.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_public_user_grouped_games(
  p_target_user_id uuid
)
RETURNS TABLE(
  group_id text,
  name text,
  cover_url text,
  proxied_cover_url text,
  platforms jsonb[],
  total_statusxp numeric,
  avg_completion numeric,
  last_played_at timestamptz,
  game_title_ids bigint[]
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH target_user AS (
    SELECT p.id AS user_id
    FROM public.profiles p
    WHERE p.id = p_target_user_id
      AND (p.show_on_leaderboard = true OR p.id = auth.uid())
  )
  SELECT g.*
  FROM target_user tu
  CROSS JOIN LATERAL public.get_user_grouped_games(tu.user_id) g;
$$;

REVOKE ALL ON FUNCTION public.get_public_user_grouped_games(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_user_grouped_games(uuid)
  TO anon, authenticated, service_role;

COMMIT;
