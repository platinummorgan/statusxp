-- Give the affected screen reads headroom during temporary load spikes.
-- PostgREST reads RPC-level statement_timeout from the schema cache.
-- ALTER FUNCTION preserves definitions, visibility guards, grants and RLS.
BEGIN;
SET LOCAL lock_timeout = '3s';
ALTER FUNCTION public.get_user_engagement_snapshot(uuid) SET statement_timeout = '15s';
ALTER FUNCTION public.get_social_graph_snapshot(uuid, integer) SET statement_timeout = '15s';
ALTER FUNCTION public.get_social_activity_highlights(uuid, integer) SET statement_timeout = '15s';
ALTER FUNCTION public.get_play_next_recommendations(uuid, integer) SET statement_timeout = '15s';
ALTER FUNCTION public.get_user_grouped_games(uuid) SET statement_timeout = '15s';
ALTER FUNCTION public.get_public_user_grouped_games(uuid) SET statement_timeout = '15s';
ALTER FUNCTION public.get_public_user_grouped_games_snapshot(uuid) SET statement_timeout = '15s';
ALTER FUNCTION public.get_most_time_sunk_game_v2(uuid) SET statement_timeout = '15s';
NOTIFY pgrst, 'reload schema';
COMMIT;
