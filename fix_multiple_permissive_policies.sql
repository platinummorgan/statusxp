-- Fix Multiple Permissive Policies (120 warnings)
-- Consolidate overlapping RLS policies into single policies with OR conditions
-- Multiple permissive policies force PostgreSQL to evaluate each one separately

-- =================================================================
-- profiles table
-- Currently has 2 duplicate policies for each operation across multiple roles
-- Consolidate into single policies
-- =================================================================

-- Remove duplicate policies
DROP POLICY IF EXISTS "Users can modify their own rows" ON profiles;
DROP POLICY IF EXISTS "Users can modify their own profile" ON profiles;
DROP POLICY IF EXISTS "Anyone can view profiles" ON profiles;
DROP POLICY IF EXISTS "Anyone can view profiles for leaderboards" ON profiles;

-- Create single consolidated policies
CREATE POLICY "profiles_select_policy"
  ON profiles FOR SELECT
  USING (true);  -- Public read access for leaderboards

CREATE POLICY "profiles_modify_policy"
  ON profiles FOR INSERT
  WITH CHECK ((select auth.uid()) = id);

CREATE POLICY "profiles_update_policy"
  ON profiles FOR UPDATE
  USING ((select auth.uid()) = id);

CREATE POLICY "profiles_delete_policy"
  ON profiles FOR DELETE
  USING ((select auth.uid()) = id);

-- =================================================================
-- user_profile_settings table
-- Has 2 SELECT policies (read + modify)
-- =================================================================

DROP POLICY IF EXISTS "Users can read their own rows" ON user_profile_settings;
DROP POLICY IF EXISTS "Users can modify their own rows" ON user_profile_settings;

CREATE POLICY "user_profile_settings_policy"
  ON user_profile_settings FOR ALL
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- trophy_room_shelves table
-- Has 2 SELECT policies (read + modify)
-- =================================================================

DROP POLICY IF EXISTS "Users can read their own rows" ON trophy_room_shelves;
DROP POLICY IF EXISTS "Users can modify their own rows" ON trophy_room_shelves;

CREATE POLICY "trophy_room_shelves_policy"
  ON trophy_room_shelves FOR ALL
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- trophy_room_items table
-- Has 2 SELECT policies (read + modify)
-- Note: trophy_room_items has shelf_id, must join to get user_id
-- =================================================================

DROP POLICY IF EXISTS "Users can read their own rows" ON trophy_room_items;
DROP POLICY IF EXISTS "Users can modify their own rows" ON trophy_room_items;

CREATE POLICY "trophy_room_items_policy"
  ON trophy_room_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM trophy_room_shelves 
      WHERE trophy_room_shelves.id = trophy_room_items.shelf_id 
      AND trophy_room_shelves.user_id = (select auth.uid())
    )
  );

-- =================================================================
-- user_selected_title table
-- Has 2 SELECT policies (view + upsert)
-- =================================================================

DROP POLICY IF EXISTS "Users can view their own selected title" ON user_selected_title;
DROP POLICY IF EXISTS "Users can upsert their own selected title" ON user_selected_title;

CREATE POLICY "user_selected_title_policy"
  ON user_selected_title FOR ALL
  USING ((select auth.uid()) = user_id);

-- =================================================================
-- achievements table
-- Has 2 SELECT policies (Anyone + Service)
-- =================================================================

DROP POLICY IF EXISTS "Anyone view achievements" ON achievements;
DROP POLICY IF EXISTS "Service full access achievements" ON achievements;

CREATE POLICY "achievements_read_policy"
  ON achievements FOR SELECT
  USING (true);  -- Public read access

CREATE POLICY "achievements_service_policy"
  ON achievements FOR ALL
  USING (current_user = 'service_role');

-- =================================================================
-- game_titles table
-- Has 2 SELECT policies (Anyone + Service)
-- =================================================================

DROP POLICY IF EXISTS "Anyone view game_titles" ON game_titles;
DROP POLICY IF EXISTS "Service full access game_titles" ON game_titles;

CREATE POLICY "game_titles_read_policy"
  ON game_titles FOR SELECT
  USING (true);  -- Public read access

CREATE POLICY "game_titles_service_policy"
  ON game_titles FOR ALL
  USING (current_user = 'service_role');

-- =================================================================
-- trophies table
-- Has 2 SELECT policies (Anyone + Service)
-- =================================================================

DROP POLICY IF EXISTS "Anyone view trophies" ON trophies;
DROP POLICY IF EXISTS "Service full access trophies" ON trophies;

CREATE POLICY "trophies_read_policy"
  ON trophies FOR SELECT
  USING (true);  -- Public read access

CREATE POLICY "trophies_service_policy"
  ON trophies FOR ALL
  USING (current_user = 'service_role');

-- =================================================================
-- user_achievements table
-- Has 2 SELECT policies (Service + Users)
-- =================================================================

DROP POLICY IF EXISTS "Service full access user_achievements" ON user_achievements;
DROP POLICY IF EXISTS "Users view own user_achievements" ON user_achievements;

CREATE POLICY "user_achievements_select_policy"
  ON user_achievements FOR SELECT
  USING (
    current_user = 'service_role' OR 
    (select auth.uid()) = user_id
  );

CREATE POLICY "user_achievements_modify_policy"
  ON user_achievements FOR ALL
  USING (current_user = 'service_role');

-- =================================================================
-- user_games table
-- Has 4 SELECT policies and 2 policies for INSERT/UPDATE/DELETE
-- =================================================================

DROP POLICY IF EXISTS "Anyone can view user games for leaderboards" ON user_games;
DROP POLICY IF EXISTS "Service full access user_games" ON user_games;
DROP POLICY IF EXISTS "Users can modify their own games" ON user_games;
DROP POLICY IF EXISTS "Users view own user_games" ON user_games;

CREATE POLICY "user_games_select_policy"
  ON user_games FOR SELECT
  USING (true);  -- Public read for leaderboards

CREATE POLICY "user_games_insert_policy"
  ON user_games FOR INSERT
  WITH CHECK (
    current_user = 'service_role' OR 
    (select auth.uid()) = user_id
  );

CREATE POLICY "user_games_update_policy"
  ON user_games FOR UPDATE
  USING (
    current_user = 'service_role' OR 
    (select auth.uid()) = user_id
  );

CREATE POLICY "user_games_delete_policy"
  ON user_games FOR DELETE
  USING (
    current_user = 'service_role' OR 
    (select auth.uid()) = user_id
  );

-- =================================================================
-- user_stats table
-- Has 2 SELECT policies (Service + Users)
-- =================================================================

DROP POLICY IF EXISTS "Service full access user_stats" ON user_stats;
DROP POLICY IF EXISTS "Users view own user_stats" ON user_stats;

CREATE POLICY "user_stats_select_policy"
  ON user_stats FOR SELECT
  USING (
    current_user = 'service_role' OR 
    (select auth.uid()) = user_id
  );

CREATE POLICY "user_stats_modify_policy"
  ON user_stats FOR ALL
  USING (current_user = 'service_role');

-- =================================================================
-- user_trophies table
-- Has 2 SELECT policies (Service + Users)
-- =================================================================

DROP POLICY IF EXISTS "Service full access user_trophies" ON user_trophies;
DROP POLICY IF EXISTS "Users view own user_trophies" ON user_trophies;

CREATE POLICY "user_trophies_select_policy"
  ON user_trophies FOR SELECT
  USING (
    current_user = 'service_role' OR 
    (select auth.uid()) = user_id
  );

CREATE POLICY "user_trophies_modify_policy"
  ON user_trophies FOR ALL
  USING (current_user = 'service_role');

-- Add verification comments
COMMENT ON TABLE profiles IS 'Consolidated RLS policies - single policy per operation type';
COMMENT ON TABLE user_games IS 'Consolidated RLS policies - public SELECT, restricted write operations';
COMMENT ON TABLE achievements IS 'Consolidated RLS policies - public read, service write';
