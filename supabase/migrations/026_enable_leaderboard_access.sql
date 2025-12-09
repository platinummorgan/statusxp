-- Migration: 026_enable_leaderboard_access.sql
-- Created: 2025-12-08
-- Description: Allow public read access to user_games and profiles for leaderboards

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Users can read their own rows" ON user_games;
DROP POLICY IF EXISTS "Users can read their own rows" ON profiles;

-- Create new policies that allow public read access
CREATE POLICY "Anyone can view user games for leaderboards"
  ON user_games
  FOR SELECT
  USING (true);

CREATE POLICY "Anyone can view profiles for leaderboards"
  ON profiles
  FOR SELECT
  USING (true);

-- Keep write restrictions
CREATE POLICY "Users can modify their own games"
  ON user_games
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can modify their own profile"
  ON profiles
  FOR ALL
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
