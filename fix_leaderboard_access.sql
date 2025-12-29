-- Fix leaderboard access - add missing SELECT policies
-- We removed the old policies but didn't add back SELECT access for public read

-- user_achievements: Allow public read for leaderboards
CREATE POLICY "user_achievements_public_read"
  ON user_achievements FOR SELECT
  USING (true);

-- Same issue might exist on other tables we modified
-- Let's check if they need public read too:

-- achievements: Allow public read
CREATE POLICY "achievements_public_read"
  ON achievements FOR SELECT
  USING (true);

-- game_titles: Allow public read
CREATE POLICY "game_titles_public_read"
  ON game_titles FOR SELECT
  USING (true);

-- trophies: Allow public read
CREATE POLICY "trophies_public_read"
  ON trophies FOR SELECT
  USING (true);

-- user_trophies: Allow public read for leaderboards
CREATE POLICY "user_trophies_public_read"
  ON user_trophies FOR SELECT
  USING (true);

-- user_stats: Allow public read
CREATE POLICY "user_stats_public_read"
  ON user_stats FOR SELECT
  USING (true);
