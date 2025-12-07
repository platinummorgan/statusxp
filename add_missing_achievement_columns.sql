-- Add missing dlc_name column to achievements table
ALTER TABLE achievements
  ADD COLUMN dlc_name text;

-- Also add missing xbox_progression_state column
ALTER TABLE achievements
  ADD COLUMN xbox_progression_state text 
  CHECK (xbox_progression_state IN ('Unknown', 'Achieved', 'NotStarted', 'InProgress', NULL));
