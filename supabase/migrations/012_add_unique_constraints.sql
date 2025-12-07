-- Migration: 012_add_unique_constraints.sql
-- Created: 2025-12-06
-- Description: Add unique constraints for platform-specific game identifiers

-- Add unique constraint for PSN communication ID
alter table game_titles
  add constraint game_titles_psn_np_communication_id_key 
  unique (psn_np_communication_id);

-- Add unique constraint for Xbox title ID  
alter table game_titles
  add constraint game_titles_xbox_title_id_key 
  unique (xbox_title_id);

-- Note: Steam app_id constraint will be added when Steam integration is implemented
