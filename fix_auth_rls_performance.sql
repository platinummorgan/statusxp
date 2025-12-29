-- Fix auth RLS InitPlan Performance (58 warnings)
-- Replace auth.uid() with (select auth.uid()) to evaluate once per query instead of per row

-- This file will recreate all affected RLS policies with optimized auth function calls
-- The fix wraps auth.uid() in a subquery so PostgreSQL evaluates it once and reuses the result

-- =================================================================
-- profiles table (2 policies affected)
-- Note: profiles.id is the user_id (references auth.users(id))
-- =================================================================

-- Users can modify their own rows
DROP POLICY IF EXISTS "Users can modify their own rows" ON profiles;
CREATE POLICY "Users can modify their own rows"
  ON profiles FOR ALL
  USING ((select auth.uid()) = id);

-- Users can modify their own profile  
DROP POLICY IF EXISTS "Users can modify their own profile" ON profiles;
CREATE POLICY "Users can modify their own profile"
  ON profiles FOR ALL
  USING ((select auth.uid()) = id);

-- =================================================================
-- user_profile_settings table (2 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can read their own rows" ON user_profile_settings;
CREATE POLICY "Users can read their own rows"
  ON user_profile_settings FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can modify their own rows" ON user_profile_settings;
CREATE POLICY "Users can modify their own rows"
  ON user_profile_settings FOR ALL
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- trophy_room_shelves table (2 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can read their own rows" ON trophy_room_shelves;
CREATE POLICY "Users can read their own rows"
  ON trophy_room_shelves FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can modify their own rows" ON trophy_room_shelves;
CREATE POLICY "Users can modify their own rows"
  ON trophy_room_shelves FOR ALL
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- trophy_room_items table (2 policies affected)
-- Note: trophy_room_items has shelf_id, need to join to get user_id
-- =================================================================

DROP POLICY IF EXISTS "Users can read their own rows" ON trophy_room_items;
CREATE POLICY "Users can read their own rows"
  ON trophy_room_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM trophy_room_shelves 
      WHERE trophy_room_shelves.id = trophy_room_items.shelf_id 
      AND trophy_room_shelves.user_id = (select auth.uid())
    )
  );

DROP POLICY IF EXISTS "Users can modify their own rows" ON trophy_room_items;
CREATE POLICY "Users can modify their own rows"
  ON trophy_room_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM trophy_room_shelves 
      WHERE trophy_room_shelves.id = trophy_room_items.shelf_id 
      AND trophy_room_shelves.user_id = (select auth.uid())
    )
  );

-- =================================================================
-- display_case_items table (1 policy affected)
-- =================================================================

DROP POLICY IF EXISTS "display_case_items_user_policy" ON display_case_items;
CREATE POLICY "display_case_items_user_policy"
  ON display_case_items FOR ALL
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- xbox_sync_log table (2 policies affected - singular table name)
-- Note: Skip xbox_sync_logs (plural) - doesn't exist
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own Xbox sync logs" ON xbox_sync_log;
CREATE POLICY "Users can view their own Xbox sync logs"
  ON xbox_sync_log FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own Xbox sync logs" ON xbox_sync_log;
CREATE POLICY "Users can insert their own Xbox sync logs"
  ON xbox_sync_log FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own Xbox sync logs" ON xbox_sync_log;
CREATE POLICY "Users can update their own Xbox sync logs"
  ON xbox_sync_log FOR UPDATE
  USING ((select auth.uid()) = user_id);

-- Note: steam_sync_logs table doesn't exist in migrations - skipping

-- Note: psn_sync_logs (plural) doesn't exist - skipping

-- =================================================================
-- user_games table (2 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users view own user_games" ON user_games;
CREATE POLICY "Users view own user_games"
  ON user_games FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can modify their own games" ON user_games;
CREATE POLICY "Users can modify their own games"
  ON user_games FOR ALL
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- user_achievements table (1 policy affected)
-- =================================================================

DROP POLICY IF EXISTS "Users view own user_achievements" ON user_achievements;
CREATE POLICY "Users view own user_achievements"
  ON user_achievements FOR SELECT
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- user_trophies table (1 policy affected)
-- =================================================================

DROP POLICY IF EXISTS "Users view own user_trophies" ON user_trophies;
CREATE POLICY "Users view own user_trophies"
  ON user_trophies FOR SELECT
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- user_stats table (1 policy affected)
-- =================================================================

DROP POLICY IF EXISTS "Users view own user_stats" ON user_stats;
CREATE POLICY "Users view own user_stats"
  ON user_stats FOR SELECT
  USING ((select auth.uid()) = user_id);

-- Note: flex_room_data table doesn't exist in migrations - skipping

-- =================================================================
-- user_meta_achievements table (3 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own meta achievements" ON user_meta_achievements;
CREATE POLICY "Users can view their own meta achievements"
  ON user_meta_achievements FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can unlock their own meta achievements" ON user_meta_achievements;
CREATE POLICY "Users can unlock their own meta achievements"
  ON user_meta_achievements FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own meta achievements" ON user_meta_achievements;
CREATE POLICY "Users can update their own meta achievements"
  ON user_meta_achievements FOR UPDATE
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- user_selected_title table (2 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own selected title" ON user_selected_title;
CREATE POLICY "Users can view their own selected title"
  ON user_selected_title FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can upsert their own selected title" ON user_selected_title;
CREATE POLICY "Users can upsert their own selected title"
  ON user_selected_title FOR ALL
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- user_ai_credits table (3 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own AI credits" ON user_ai_credits;
CREATE POLICY "Users can view their own AI credits"
  ON user_ai_credits FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own AI credits" ON user_ai_credits;
CREATE POLICY "Users can update their own AI credits"
  ON user_ai_credits FOR UPDATE
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own AI credits" ON user_ai_credits;
CREATE POLICY "Users can insert their own AI credits"
  ON user_ai_credits FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

-- =================================================================
-- psn_sync_log table (3 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own PSN sync logs" ON psn_sync_log;
CREATE POLICY "Users can view their own PSN sync logs"
  ON psn_sync_log FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own PSN sync logs" ON psn_sync_log;
CREATE POLICY "Users can insert their own PSN sync logs"
  ON psn_sync_log FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own PSN sync logs" ON psn_sync_log;
CREATE POLICY "Users can update their own PSN sync logs"
  ON psn_sync_log FOR UPDATE
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- psn_user_trophy_profile table (3 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own PSN trophy profile" ON psn_user_trophy_profile;
CREATE POLICY "Users can view their own PSN trophy profile"
  ON psn_user_trophy_profile FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own PSN trophy profile" ON psn_user_trophy_profile;
CREATE POLICY "Users can insert their own PSN trophy profile"
  ON psn_user_trophy_profile FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own PSN trophy profile" ON psn_user_trophy_profile;
CREATE POLICY "Users can update their own PSN trophy profile"
  ON psn_user_trophy_profile FOR UPDATE
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- user_premium_status table (3 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own premium status" ON user_premium_status;
CREATE POLICY "Users can view their own premium status"
  ON user_premium_status FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update their own premium status" ON user_premium_status;
CREATE POLICY "Users can update their own premium status"
  ON user_premium_status FOR UPDATE
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own premium status" ON user_premium_status;
CREATE POLICY "Users can insert their own premium status"
  ON user_premium_status FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

-- =================================================================
-- user_sync_history table (2 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own sync history" ON user_sync_history;
CREATE POLICY "Users can view their own sync history"
  ON user_sync_history FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own sync history" ON user_sync_history;
CREATE POLICY "Users can insert their own sync history"
  ON user_sync_history FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

-- =================================================================
-- user_ai_daily_usage table (2 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own AI usage" ON user_ai_daily_usage;
CREATE POLICY "Users can view their own AI usage"
  ON user_ai_daily_usage FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own AI usage" ON user_ai_daily_usage;
CREATE POLICY "Users can insert their own AI usage"
  ON user_ai_daily_usage FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

-- =================================================================
-- user_ai_pack_purchases table (2 policies affected)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own purchase history" ON user_ai_pack_purchases;
CREATE POLICY "Users can view their own purchase history"
  ON user_ai_pack_purchases FOR SELECT
  USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert their own purchases" ON user_ai_pack_purchases;
CREATE POLICY "Users can insert their own purchases"
  ON user_ai_pack_purchases FOR INSERT
  WITH CHECK ((select auth.uid()) = user_id);

-- Add verification comment
COMMENT ON TABLE profiles IS 'User profiles with optimized RLS policies using (select auth.uid())';
