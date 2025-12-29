-- Fix Remaining 43 Performance Warnings
-- Part 1: Auth RLS InitPlan for plural sync tables + flex_room_data (13 warnings)
-- Part 2: Service role policies creating duplicate SELECT access (30 warnings)

-- =================================================================
-- PART 1: Fix auth.uid() performance on remaining tables
-- =================================================================

-- xbox_sync_logs (plural - different from xbox_sync_log)
DROP POLICY IF EXISTS "Users can view own Xbox sync logs" ON xbox_sync_logs;
CREATE POLICY "Users can view own Xbox sync logs"
  ON xbox_sync_logs FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert own Xbox sync logs" ON xbox_sync_logs;
CREATE POLICY "Users can insert own Xbox sync logs"
  ON xbox_sync_logs FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own Xbox sync logs" ON xbox_sync_logs;
CREATE POLICY "Users can update own Xbox sync logs"
  ON xbox_sync_logs FOR UPDATE
  USING ((select auth.uid()) = user_id);

-- steam_sync_logs
DROP POLICY IF EXISTS "Users can view own Steam sync logs" ON steam_sync_logs;
CREATE POLICY "Users can view own Steam sync logs"
  ON steam_sync_logs FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert own Steam sync logs" ON steam_sync_logs;
CREATE POLICY "Users can insert own Steam sync logs"
  ON steam_sync_logs FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own Steam sync logs" ON steam_sync_logs;
CREATE POLICY "Users can update own Steam sync logs"
  ON steam_sync_logs FOR UPDATE
  USING ((select auth.uid()) = user_id);

-- psn_sync_logs (plural - different from psn_sync_log)
DROP POLICY IF EXISTS "Users can view own PSN sync logs" ON psn_sync_logs;
CREATE POLICY "Users can view own PSN sync logs"
  ON psn_sync_logs FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert own PSN sync logs" ON psn_sync_logs;
CREATE POLICY "Users can insert own PSN sync logs"
  ON psn_sync_logs FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own PSN sync logs" ON psn_sync_logs;
CREATE POLICY "Users can update own PSN sync logs"
  ON psn_sync_logs FOR UPDATE
  USING ((select auth.uid()) = user_id);

-- flex_room_data
DROP POLICY IF EXISTS "Users can view their own flex room data" ON flex_room_data;
CREATE POLICY "Users can view their own flex room data"
  ON flex_room_data FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own flex room data" ON flex_room_data;
CREATE POLICY "Users can insert their own flex room data"
  ON flex_room_data FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own flex room data" ON flex_room_data;
CREATE POLICY "Users can update their own flex room data"
  ON flex_room_data FOR UPDATE
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete their own flex room data" ON flex_room_data;
CREATE POLICY "Users can delete their own flex room data"
  ON flex_room_data FOR DELETE
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- PART 2: Fix service role policies to not apply to SELECT
-- This eliminates duplicate policy evaluation
-- =================================================================

-- achievements: Service role should only handle write operations
DROP POLICY IF EXISTS "achievements_service_policy" ON achievements;
CREATE POLICY "achievements_service_policy"
  ON achievements FOR INSERT
  WITH CHECK (current_user = 'service_role');

CREATE POLICY "achievements_service_update"
  ON achievements FOR UPDATE
  USING (current_user = 'service_role');

CREATE POLICY "achievements_service_delete"
  ON achievements FOR DELETE
  USING (current_user = 'service_role');

-- game_titles: Service role should only handle write operations
DROP POLICY IF EXISTS "game_titles_service_policy" ON game_titles;
CREATE POLICY "game_titles_service_policy"
  ON game_titles FOR INSERT
  WITH CHECK (current_user = 'service_role');

CREATE POLICY "game_titles_service_update"
  ON game_titles FOR UPDATE
  USING (current_user = 'service_role');

CREATE POLICY "game_titles_service_delete"
  ON game_titles FOR DELETE
  USING (current_user = 'service_role');

-- trophies: Service role should only handle write operations
DROP POLICY IF EXISTS "trophies_service_policy" ON trophies;
CREATE POLICY "trophies_service_policy"
  ON trophies FOR INSERT
  WITH CHECK (current_user = 'service_role');

CREATE POLICY "trophies_service_update"
  ON trophies FOR UPDATE
  USING (current_user = 'service_role');

CREATE POLICY "trophies_service_delete"
  ON trophies FOR DELETE
  USING (current_user = 'service_role');

-- user_achievements: Service modify policy should not apply to SELECT
DROP POLICY IF EXISTS "user_achievements_modify_policy" ON user_achievements;
CREATE POLICY "user_achievements_modify_insert"
  ON user_achievements FOR INSERT
  WITH CHECK (current_user = 'service_role');

CREATE POLICY "user_achievements_modify_update"
  ON user_achievements FOR UPDATE
  USING (current_user = 'service_role');

CREATE POLICY "user_achievements_modify_delete"
  ON user_achievements FOR DELETE
  USING (current_user = 'service_role');

-- user_stats: Service modify policy should not apply to SELECT
DROP POLICY IF EXISTS "user_stats_modify_policy" ON user_stats;
CREATE POLICY "user_stats_modify_insert"
  ON user_stats FOR INSERT
  WITH CHECK (current_user = 'service_role');

CREATE POLICY "user_stats_modify_update"
  ON user_stats FOR UPDATE
  USING (current_user = 'service_role');

CREATE POLICY "user_stats_modify_delete"
  ON user_stats FOR DELETE
  USING (current_user = 'service_role');

-- user_trophies: Service modify policy should not apply to SELECT
DROP POLICY IF EXISTS "user_trophies_modify_policy" ON user_trophies;
CREATE POLICY "user_trophies_modify_insert"
  ON user_trophies FOR INSERT
  WITH CHECK (current_user = 'service_role');

CREATE POLICY "user_trophies_modify_update"
  ON user_trophies FOR UPDATE
  USING (current_user = 'service_role');

CREATE POLICY "user_trophies_modify_delete"
  ON user_trophies FOR DELETE
  USING (current_user = 'service_role');

-- Verification
COMMENT ON TABLE xbox_sync_logs IS 'Optimized: auth.uid() wrapped in subquery, single policy per operation';
COMMENT ON TABLE achievements IS 'Optimized: Separate read and write policies to eliminate duplicate evaluation';
