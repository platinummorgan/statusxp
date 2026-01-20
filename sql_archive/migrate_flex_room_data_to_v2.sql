-- Migrate flex_room_data table from V1 (achievement_id) to V2 (composite keys)

-- Drop the old table and recreate with composite keys
DROP TABLE IF EXISTS flex_room_data CASCADE;

CREATE TABLE flex_room_data (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tagline TEXT DEFAULT 'Completionist',
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  
  -- Featured tiles - now using composite keys
  flex_of_all_time_platform_id BIGINT,
  flex_of_all_time_platform_game_id TEXT,
  flex_of_all_time_platform_achievement_id TEXT,
  
  rarest_flex_platform_id BIGINT,
  rarest_flex_platform_game_id TEXT,
  rarest_flex_platform_achievement_id TEXT,
  
  most_time_sunk_platform_id BIGINT,
  most_time_sunk_platform_game_id TEXT,
  most_time_sunk_platform_achievement_id TEXT,
  
  sweatiest_platinum_platform_id BIGINT,
  sweatiest_platinum_platform_game_id TEXT,
  sweatiest_platinum_platform_achievement_id TEXT,
  
  -- Superlatives stored as JSONB with composite keys
  -- Format: { "category_id": { "platform_id": 1, "platform_game_id": "...", "platform_achievement_id": "..." } }
  superlatives JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add foreign key constraints for featured tiles
ALTER TABLE flex_room_data
  ADD CONSTRAINT fk_flex_of_all_time 
  FOREIGN KEY (flex_of_all_time_platform_id, flex_of_all_time_platform_game_id, flex_of_all_time_platform_achievement_id)
  REFERENCES achievements(platform_id, platform_game_id, platform_achievement_id)
  ON DELETE SET NULL;

ALTER TABLE flex_room_data
  ADD CONSTRAINT fk_rarest_flex
  FOREIGN KEY (rarest_flex_platform_id, rarest_flex_platform_game_id, rarest_flex_platform_achievement_id)
  REFERENCES achievements(platform_id, platform_game_id, platform_achievement_id)
  ON DELETE SET NULL;

ALTER TABLE flex_room_data
  ADD CONSTRAINT fk_most_time_sunk
  FOREIGN KEY (most_time_sunk_platform_id, most_time_sunk_platform_game_id, most_time_sunk_platform_achievement_id)
  REFERENCES achievements(platform_id, platform_game_id, platform_achievement_id)
  ON DELETE SET NULL;

ALTER TABLE flex_room_data
  ADD CONSTRAINT fk_sweatiest_platinum
  FOREIGN KEY (sweatiest_platinum_platform_id, sweatiest_platinum_platform_game_id, sweatiest_platinum_platform_achievement_id)
  REFERENCES achievements(platform_id, platform_game_id, platform_achievement_id)
  ON DELETE SET NULL;

-- Enable RLS
ALTER TABLE flex_room_data ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own flex room data"
  ON flex_room_data FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own flex room data"
  ON flex_room_data FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own flex room data"
  ON flex_room_data FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own flex room data"
  ON flex_room_data FOR DELETE
  USING (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON flex_room_data TO authenticated;
