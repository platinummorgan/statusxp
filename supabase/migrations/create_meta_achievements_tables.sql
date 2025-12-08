-- Meta-achievements: In-app achievements users earn for various milestones
-- These are separate from game trophies/achievements

-- Table: meta_achievements
-- Defines all possible meta-achievements users can earn
CREATE TABLE IF NOT EXISTS public.meta_achievements (
  id TEXT PRIMARY KEY, -- e.g., 'rare_air', 'baller', 'one_percenter'
  category TEXT NOT NULL, -- 'rarity', 'volume', 'streak', 'platform', 'completion', 'time', 'variety', 'meta'
  default_title TEXT NOT NULL, -- The default display name, e.g., "Rare Air"
  description TEXT NOT NULL, -- What the user did to earn it
  icon_emoji TEXT, -- Optional emoji for quick visual
  sort_order INTEGER NOT NULL DEFAULT 0, -- For display ordering
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table: user_meta_achievements
-- Tracks which meta-achievements each user has unlocked
CREATE TABLE IF NOT EXISTS public.user_meta_achievements (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id TEXT NOT NULL REFERENCES public.meta_achievements(id) ON DELETE CASCADE,
  custom_title TEXT, -- User can rename their achievement title
  unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

-- Table: user_selected_title
-- Tracks which meta-achievement title the user is currently displaying
CREATE TABLE IF NOT EXISTS public.user_selected_title (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  achievement_id TEXT REFERENCES public.meta_achievements(id) ON DELETE SET NULL,
  custom_title TEXT, -- The custom title if they renamed it
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_meta_achievements_user_id ON public.user_meta_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_meta_achievements_achievement_id ON public.user_meta_achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_meta_achievements_category ON public.meta_achievements(category);

-- RLS Policies
ALTER TABLE public.meta_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_meta_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_selected_title ENABLE ROW LEVEL SECURITY;

-- Everyone can read all meta-achievements (they're public definitions)
CREATE POLICY "Anyone can view meta achievements"
  ON public.meta_achievements FOR SELECT
  USING (true);

-- Users can view their own unlocked achievements
CREATE POLICY "Users can view their own meta achievements"
  ON public.user_meta_achievements FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own achievements (when system unlocks them)
CREATE POLICY "Users can unlock their own meta achievements"
  ON public.user_meta_achievements FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update custom titles on their own achievements
CREATE POLICY "Users can update their own meta achievements"
  ON public.user_meta_achievements FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can view their own selected title
CREATE POLICY "Users can view their own selected title"
  ON public.user_selected_title FOR SELECT
  USING (auth.uid() = user_id);

-- Users can update their own selected title
CREATE POLICY "Users can upsert their own selected title"
  ON public.user_selected_title FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Insert all 50 meta-achievements
INSERT INTO public.meta_achievements (id, category, default_title, description, icon_emoji, sort_order) VALUES
-- Rarity-based flex (10)
('rare_air', 'rarity', 'Rare Air', 'Earn 1 trophy/achievement with rarity < 5%', '💎', 1),
('baller', 'rarity', 'Baller', 'Earn 1 trophy/achievement with rarity < 2%', '🏀', 2),
('diamond_hands', 'rarity', 'Diamond Hands', 'Earn 5 trophies/achievements with rarity < 5%', '💎', 3),
('mythic_hunter', 'rarity', 'Mythic Hunter', 'Earn 10 trophies/achievements with rarity < 5%', '🔮', 4),
('elite_finish', 'rarity', 'Elite Finish', 'Earn 1 platinum/100% game with rarity < 10%', '🏆', 5),
('sweat_lord', 'rarity', 'Sweat Lord', 'Earn 1 platinum/100% game with rarity < 5%', '💧', 6),
('one_percenter', 'rarity', 'One-Percenter', 'Earn 1 trophy/achievement with rarity < 1%', '👑', 7),
('dlc_demon', 'rarity', 'DLC Demon', 'Earn a full DLC list where average rarity < 10%', '😈', 8),
('never_casual', 'rarity', 'Never Casual', 'Earn 25 trophies/achievements all rarer than 20%', '🎯', 9),
('fresh_flex', 'rarity', 'Fresh Flex', 'Earn your rarest trophy in the last 7 days', '✨', 10),

-- Volume / grind (10)
('warming_up', 'volume', 'Warming Up', 'Earn 50 trophies/achievements total', '🔥', 11),
('on_the_grind', 'volume', 'On the Grind', 'Earn 250 trophies/achievements total', '⚙️', 12),
('xp_machine', 'volume', 'XP Machine', 'Earn 500 trophies/achievements total', '🤖', 13),
('achievement_engine', 'volume', 'Achievement Engine', 'Earn 1000 trophies/achievements total', '🚀', 14),
('no_life_great_life', 'volume', 'No Life, Great Life', 'Earn 2500 trophies/achievements total', '🎮', 15),
('double_digits', 'volume', 'Double Digits', 'Earn 10 platinums/100% game completions', '🔟', 16),
('certified_platinum', 'volume', 'Certified Platinum', 'Earn 25 platinums/100% completions', '📜', 17),
('legendary_finisher', 'volume', 'Legendary Finisher', 'Earn 50 platinums/100% completions', '🏅', 18),
('spike_week', 'volume', 'Spike Week', 'Complete 3 games to 100% in one week', '⚡', 19),
('power_session', 'volume', 'Power Session', 'Earn 100 trophies/achievements within 24 hours', '💪', 20),

-- Streaks / consistency (5)
('one_week_streak', 'streak', 'One-Week Streak', 'Earn at least 1 trophy/achievement 7 days in a row', '📅', 21),
('daily_grinder', 'streak', 'Daily Grinder', 'Earn at least 1 trophy/achievement 30 days in a row', '🔁', 22),
('no_days_off', 'streak', 'No Days Off', 'Earn at least 5 trophies/achievements every day for 7 days', '💯', 23),
('touch_grass', 'streak', 'Touch Grass', 'Go 7 days without earning anything', '🌿', 24),
('instant_gratification', 'streak', 'Instant Gratification', 'Earn a trophy/achievement within 10 minutes of launching a game', '⏱️', 25),

-- Platform-specific (5)
('welcome_trophy_room', 'platform', 'Welcome to the Trophy Room', 'Earn your first PlayStation trophy tracked in the app', '🎮', 26),
('welcome_gamerscore', 'platform', 'Welcome to the GamerScore', 'Earn your first Xbox achievement tracked', '🎯', 27),
('welcome_pc_grind', 'platform', 'Welcome to the PC Grind', 'Earn your first Steam achievement tracked', '💻', 28),
('triforce', 'platform', 'Triforce', 'Earn at least one achievement on all three platforms', '🔺', 29),
('cross_platform_conqueror', 'platform', 'Cross-Platform Conqueror', 'Get a platinum on PlayStation, 1000G on Xbox, and 100% on Steam', '🌐', 30),

-- Completion percentage & clean-up (5)
('big_comeback', 'completion', 'Big Comeback', 'Take a game from <10% → ≥50% completion', '↗️', 31),
('closer', 'completion', 'Closer', 'Take a game from <50% → 100% completion', '🎯', 32),
('so_close_it_hurts', 'completion', 'So Close It Hurts', 'Finish clearing all but 1 trophy/achievement in a game', '😤', 33),
('janitor_duty', 'completion', 'Janitor Duty', 'Clean up every outstanding bronze/low-value trophy in a game', '🧹', 34),
('glow_up', 'completion', 'Glow-Up', 'Raise your overall average completion across all games by 5 percentage points', '✨', 35),

-- Time / session flavored (5)
('night_owl', 'time', 'Night Owl', 'Earn a trophy/achievement between 2–4 AM local time', '🦉', 36),
('early_grind', 'time', 'Early Grind', 'Earn a trophy/achievement before 7 AM', '🌅', 37),
('speedrun_finish', 'time', 'Speedrun Finish', 'Earn a platinum/100% in a single calendar day from first trophy to last', '⚡', 38),
('new_year_new_flex', 'time', 'New Year, New Flex', 'Earn your first trophy/achievement of a new year', '🎉', 39),
('birthday_buff', 'time', 'Birthday Buff', 'Earn a trophy/achievement on your birthday', '🎂', 40),

-- Game variety / taste profile (5)
('game_hopper', 'variety', 'Game Hopper', 'Earn trophies/achievements in 5 different games in one day', '🦘', 41),
('library_card', 'variety', 'Library Card', 'Earn trophies/achievements in 100 unique games total', '📚', 42),
('multi_class_nerd', 'variety', 'Multi-Class Nerd', 'Earn a platinum/100% in 3 games of different genres', '🎭', 43),
('fearless', 'variety', 'Fearless', 'Earn at least one horror game completion', '👻', 44),
('big_brain_energy', 'variety', 'Big Brain Energy', 'Earn at least one puzzle/brainy game completion', '🧠', 45),

-- Meta / app-specific flex (5)
('systems_online', 'meta', 'Systems Online', 'Sync all three platforms at least once', '🔄', 46),
('interior_designer', 'meta', 'Interior Designer', 'Customize all slots in your Flex Room', '🏠', 47),
('profile_pimp', 'meta', 'Profile Pimp', 'Set a custom avatar + banner inside the app', '🎨', 48),
('showboat', 'meta', 'Showboat', 'Share/export a StatusXP poster / profile card once', '📤', 49),
('rank_up_irl', 'meta', 'Rank Up IRL', 'Hit a personal StatusXP total threshold (10,000)', '⭐', 50)
ON CONFLICT (id) DO NOTHING;
