-- Achievement System - Schema Additions Needed
-- Run this to see what achievements still need database schema changes

/*
ACHIEVEMENTS REQUIRING NEW SCHEMA:

1. COMPLETION HISTORY TABLE (for 4 achievements):
   - big_comeback: Track when a game goes from <10% → ≥50%
   - closer: Track when a game goes from <50% → 100%
   - janitor_duty: Track bronze/low-value trophy cleanup
   - glow_up: Track overall average completion percentage over time
   
   Suggested table:
   CREATE TABLE completion_history (
     id BIGSERIAL PRIMARY KEY,
     user_id UUID REFERENCES profiles(id),
     game_title_id BIGINT REFERENCES game_titles(id),
     completion_percent NUMERIC(5,2),
     recorded_at TIMESTAMPTZ DEFAULT NOW()
   );

2. GENRE DATA (for 3 achievements):
   - multi_class_nerd: Need genre field in game_titles
   - fearless: Need to identify horror games
   - big_brain_energy: Need to identify puzzle games
   
   Suggested addition:
   ALTER TABLE game_titles ADD COLUMN genre TEXT;
   ALTER TABLE game_titles ADD COLUMN genres TEXT[]; -- for multiple genres

3. USER BIRTHDAY (for 1 achievement):
   - birthday_buff: Need birthday in profiles table
   
   Suggested addition:
   ALTER TABLE profiles ADD COLUMN birthday DATE;

4. GAME SESSION TRACKING (for 2 achievements):
   - instant_gratification: Track game launch times
   - speedrun_finish: Track when platinum was actually earned
   
   Suggested table:
   CREATE TABLE game_sessions (
     id BIGSERIAL PRIMARY KEY,
     user_id UUID REFERENCES profiles(id),
     game_title_id BIGINT REFERENCES game_titles(id),
     started_at TIMESTAMPTZ,
     ended_at TIMESTAMPTZ
   );

5. CUSTOM PROFILE DATA (for 2 achievements):
   - profile_pimp: Need custom avatar/banner upload feature
   - showboat: Need sharing/export feature
   
   Suggested additions:
   ALTER TABLE profiles ADD COLUMN custom_avatar_url TEXT;
   ALTER TABLE profiles ADD COLUMN custom_banner_url TEXT;
   
   CREATE TABLE shared_profiles (
     id BIGSERIAL PRIMARY KEY,
     user_id UUID REFERENCES profiles(id),
     shared_at TIMESTAMPTZ DEFAULT NOW(),
     share_type TEXT -- 'poster', 'card', etc.
   );
*/

-- For now, let's add the simplest ones:

-- Add birthday field
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS birthday DATE;

-- Add genre support (array allows multiple genres per game)
ALTER TABLE game_titles ADD COLUMN IF NOT EXISTS genres TEXT[];

-- Create completion history table
CREATE TABLE IF NOT EXISTS completion_history (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  game_title_id BIGINT REFERENCES game_titles(id) ON DELETE CASCADE,
  completion_percent NUMERIC(5,2),
  earned_trophies INT,
  recorded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_completion_history_user 
  ON completion_history(user_id, game_title_id, recorded_at DESC);

-- Create trigger to automatically track completion changes
CREATE OR REPLACE FUNCTION track_completion_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- Only insert if completion actually changed
  IF (TG_OP = 'INSERT') OR 
     (TG_OP = 'UPDATE' AND (
       OLD.completion_percent IS DISTINCT FROM NEW.completion_percent OR
       OLD.earned_trophies IS DISTINCT FROM NEW.earned_trophies
     )) THEN
    INSERT INTO completion_history (user_id, game_title_id, completion_percent, earned_trophies)
    VALUES (NEW.user_id, NEW.game_title_id, NEW.completion_percent, NEW.earned_trophies);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS track_user_games_completion ON user_games;
CREATE TRIGGER track_user_games_completion
  AFTER INSERT OR UPDATE ON user_games
  FOR EACH ROW
  EXECUTE FUNCTION track_completion_changes();
