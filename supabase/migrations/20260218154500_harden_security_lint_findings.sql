-- Harden Supabase lint findings without destructive schema changes.
-- Fixes:
-- 1) security_definer_view (set flagged views to security_invoker)
-- 2) rls_disabled_in_public (enable RLS + explicit policies)

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Views flagged as SECURITY DEFINER -> switch to SECURITY INVOKER
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'xbox_leaderboard_cache'
      AND c.relkind = 'v'
  ) THEN
    EXECUTE 'ALTER VIEW public.xbox_leaderboard_cache SET (security_invoker = true)';
  END IF;
END
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'grouped_games_cache'
      AND c.relkind = 'v'
  ) THEN
    EXECUTE 'ALTER VIEW public.grouped_games_cache SET (security_invoker = true)';
  END IF;
END
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'user_games'
      AND c.relkind = 'v'
  ) THEN
    EXECUTE 'ALTER VIEW public.user_games SET (security_invoker = true)';
  END IF;
END
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'steam_leaderboard_cache'
      AND c.relkind = 'v'
  ) THEN
    EXECUTE 'ALTER VIEW public.steam_leaderboard_cache SET (security_invoker = true)';
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 2) Enable RLS on flagged public tables
-- ---------------------------------------------------------------------------

ALTER TABLE IF EXISTS public.activity_feed ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.user_stat_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.activity_feed_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.seasonal_period_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.seasonal_leaderboard_baselines ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.leaderboard_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.psn_leaderboard_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.xbox_leaderboard_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.steam_leaderboard_history ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- 3) Policies for activity feed tables
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'activity_feed'
      AND policyname = 'activity_feed_read_visible_recent'
  ) THEN
    CREATE POLICY activity_feed_read_visible_recent
      ON public.activity_feed
      FOR SELECT
      TO authenticated
      USING (is_visible = true AND expires_at > CURRENT_DATE);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'activity_feed'
      AND policyname = 'activity_feed_service_role_all'
  ) THEN
    CREATE POLICY activity_feed_service_role_all
      ON public.activity_feed
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_stat_snapshots'
      AND policyname = 'user_stat_snapshots_select_own'
  ) THEN
    CREATE POLICY user_stat_snapshots_select_own
      ON public.user_stat_snapshots
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_stat_snapshots'
      AND policyname = 'user_stat_snapshots_service_role_all'
  ) THEN
    CREATE POLICY user_stat_snapshots_service_role_all
      ON public.user_stat_snapshots
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'activity_feed_views'
      AND policyname = 'activity_feed_views_select_own'
  ) THEN
    CREATE POLICY activity_feed_views_select_own
      ON public.activity_feed_views
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'activity_feed_views'
      AND policyname = 'activity_feed_views_insert_own'
  ) THEN
    CREATE POLICY activity_feed_views_insert_own
      ON public.activity_feed_views
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'activity_feed_views'
      AND policyname = 'activity_feed_views_update_own'
  ) THEN
    CREATE POLICY activity_feed_views_update_own
      ON public.activity_feed_views
      FOR UPDATE
      TO authenticated
      USING (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'activity_feed_views'
      AND policyname = 'activity_feed_views_service_role_all'
  ) THEN
    CREATE POLICY activity_feed_views_service_role_all
      ON public.activity_feed_views
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 4) Policies for seasonal tables
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'seasonal_period_overrides'
      AND policyname = 'seasonal_period_overrides_public_read'
  ) THEN
    CREATE POLICY seasonal_period_overrides_public_read
      ON public.seasonal_period_overrides
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'seasonal_period_overrides'
      AND policyname = 'seasonal_period_overrides_service_role_all'
  ) THEN
    CREATE POLICY seasonal_period_overrides_service_role_all
      ON public.seasonal_period_overrides
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'seasonal_leaderboard_baselines'
      AND policyname = 'seasonal_leaderboard_baselines_select_own'
  ) THEN
    CREATE POLICY seasonal_leaderboard_baselines_select_own
      ON public.seasonal_leaderboard_baselines
      FOR SELECT
      TO authenticated
      USING (auth.uid() = user_id);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'seasonal_leaderboard_baselines'
      AND policyname = 'seasonal_leaderboard_baselines_service_role_all'
  ) THEN
    CREATE POLICY seasonal_leaderboard_baselines_service_role_all
      ON public.seasonal_leaderboard_baselines
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 5) Policies for historical leaderboard tables (public read, service writes)
-- ---------------------------------------------------------------------------

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'leaderboard_history'
      AND policyname = 'leaderboard_history_public_read'
  ) THEN
    CREATE POLICY leaderboard_history_public_read
      ON public.leaderboard_history
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'leaderboard_history'
      AND policyname = 'leaderboard_history_service_role_all'
  ) THEN
    CREATE POLICY leaderboard_history_service_role_all
      ON public.leaderboard_history
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'psn_leaderboard_history'
      AND policyname = 'psn_leaderboard_history_public_read'
  ) THEN
    CREATE POLICY psn_leaderboard_history_public_read
      ON public.psn_leaderboard_history
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'psn_leaderboard_history'
      AND policyname = 'psn_leaderboard_history_service_role_all'
  ) THEN
    CREATE POLICY psn_leaderboard_history_service_role_all
      ON public.psn_leaderboard_history
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'xbox_leaderboard_history'
      AND policyname = 'xbox_leaderboard_history_public_read'
  ) THEN
    CREATE POLICY xbox_leaderboard_history_public_read
      ON public.xbox_leaderboard_history
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'xbox_leaderboard_history'
      AND policyname = 'xbox_leaderboard_history_service_role_all'
  ) THEN
    CREATE POLICY xbox_leaderboard_history_service_role_all
      ON public.xbox_leaderboard_history
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'steam_leaderboard_history'
      AND policyname = 'steam_leaderboard_history_public_read'
  ) THEN
    CREATE POLICY steam_leaderboard_history_public_read
      ON public.steam_leaderboard_history
      FOR SELECT
      TO anon, authenticated
      USING (true);
  END IF;
END
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'steam_leaderboard_history'
      AND policyname = 'steam_leaderboard_history_service_role_all'
  ) THEN
    CREATE POLICY steam_leaderboard_history_service_role_all
      ON public.steam_leaderboard_history
      FOR ALL
      TO service_role
      USING (true)
      WITH CHECK (true);
  END IF;
END
$$;

COMMIT;
