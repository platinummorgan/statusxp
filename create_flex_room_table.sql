-- Create flex_room_data table
-- Stores user-curated achievement showcase configurations

CREATE TABLE IF NOT EXISTS public.flex_room_data (
  -- Primary key
  user_id UUID NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Configuration
  -- TODO: Replace with earned Status title from in-app meta-achievements system
  tagline TEXT NOT NULL DEFAULT 'Completionist',
  last_updated TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Featured achievement IDs (NULL if not yet assigned)
  flex_of_all_time_id INTEGER REFERENCES public.achievements(id) ON DELETE SET NULL,
  rarest_flex_id INTEGER REFERENCES public.achievements(id) ON DELETE SET NULL,
  most_time_sunk_id INTEGER REFERENCES public.achievements(id) ON DELETE SET NULL,
  sweatiest_platinum_id INTEGER REFERENCES public.achievements(id) ON DELETE SET NULL,
  
  -- Superlative Wall (JSONB mapping category_id -> achievement_id)
  -- Example: {"hardest": 12345, "rng_nightmare": 67890, "most_proud": 54321}
  superlatives JSONB NOT NULL DEFAULT '{}',
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_flex_room_data_user_id ON public.flex_room_data(user_id);
CREATE INDEX IF NOT EXISTS idx_flex_room_data_last_updated ON public.flex_room_data(last_updated);

-- Enable Row Level Security
ALTER TABLE public.flex_room_data ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only read/write their own flex room data
DROP POLICY IF EXISTS "Users can view their own flex room data" ON public.flex_room_data;
CREATE POLICY "Users can view their own flex room data"
  ON public.flex_room_data
  FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own flex room data" ON public.flex_room_data;
CREATE POLICY "Users can insert their own flex room data"
  ON public.flex_room_data
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own flex room data" ON public.flex_room_data;
CREATE POLICY "Users can update their own flex room data"
  ON public.flex_room_data
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own flex room data" ON public.flex_room_data;
CREATE POLICY "Users can delete their own flex room data"
  ON public.flex_room_data
  FOR DELETE
  USING (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.flex_room_data TO authenticated;
GRANT SELECT ON public.flex_room_data TO anon;

-- Add trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_flex_room_data_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_flex_room_data_updated_at ON public.flex_room_data;
CREATE TRIGGER update_flex_room_data_updated_at
  BEFORE UPDATE ON public.flex_room_data
  FOR EACH ROW
  EXECUTE FUNCTION public.update_flex_room_data_updated_at();

-- RPC function to get game with most achievements (most time-sunk)
CREATE OR REPLACE FUNCTION public.get_most_time_sunk_game(p_user_id UUID)
RETURNS TABLE (
  game_title_id BIGINT,
  achievement_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    a.game_title_id,
    COUNT(*) AS achievement_count
  FROM public.user_achievements ua
  INNER JOIN public.achievements a ON ua.achievement_id = a.id
  WHERE ua.user_id = p_user_id
  GROUP BY a.game_title_id
  ORDER BY achievement_count DESC
  LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_most_time_sunk_game TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_most_time_sunk_game TO anon;

-- Test queries
-- SELECT * FROM public.flex_room_data WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
-- SELECT * FROM public.get_most_time_sunk_game('84b60ad6-cb2c-484f-8953-bf814551fd7a');
