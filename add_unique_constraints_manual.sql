-- Run this in Supabase SQL Editor to add unique constraints

-- Add unique constraint for PSN communication ID
ALTER TABLE game_titles
  ADD CONSTRAINT game_titles_psn_np_communication_id_key 
  UNIQUE (psn_np_communication_id);

-- Add unique constraint for Xbox title ID  
ALTER TABLE game_titles
  ADD CONSTRAINT game_titles_xbox_title_id_key 
  UNIQUE (xbox_title_id);
