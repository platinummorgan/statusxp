-- Create achievements table if it doesn't exist
CREATE TABLE IF NOT EXISTS achievements (
  id bigserial PRIMARY KEY,
  game_title_id bigint REFERENCES game_titles(id) ON DELETE CASCADE,
  platform text NOT NULL CHECK (platform IN ('psn', 'xbox', 'steam')),
  platform_achievement_id text NOT NULL,
  name text NOT NULL,
  description text,
  icon_url text,
  
  -- PSN fields
  psn_trophy_type text CHECK (psn_trophy_type IN ('bronze', 'silver', 'gold', 'platinum', null)),
  psn_trophy_group_id text,
  psn_is_secret boolean,
  
  -- Xbox fields
  xbox_gamerscore int,
  xbox_is_secret boolean,
  
  -- Steam fields
  steam_hidden boolean,
  
  -- Unified fields
  rarity_global numeric(5,2),
  is_dlc boolean DEFAULT false,
  
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  UNIQUE(game_title_id, platform, platform_achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_achievements_game_platform ON achievements(game_title_id, platform);
CREATE INDEX IF NOT EXISTS idx_achievements_platform ON achievements(platform);

-- Create user_achievements table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_achievements (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id bigint REFERENCES achievements(id) ON DELETE CASCADE,
  platform text NOT NULL CHECK (platform IN ('psn', 'xbox', 'steam')),
  unlocked_at timestamptz NOT NULL,
  platform_unlock_data jsonb,
  
  created_at timestamptz DEFAULT now(),
  
  UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_platform ON user_achievements(platform);

-- Enable RLS
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- Policies for achievements (public read)
DROP POLICY IF EXISTS "Anyone can view achievements" ON achievements;
CREATE POLICY "Anyone can view achievements"
  ON achievements
  FOR SELECT
  USING (true);

-- Policies for user_achievements (users can view their own)
DROP POLICY IF EXISTS "Users can view own achievements" ON user_achievements;
CREATE POLICY "Users can view own achievements"
  ON user_achievements
  FOR SELECT
  USING (auth.uid() = user_id);
