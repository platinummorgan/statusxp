-- Display Case Items Table
-- Stores user's custom trophy display arrangement

CREATE TABLE IF NOT EXISTS display_case_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trophy_id INTEGER NOT NULL REFERENCES trophies(id) ON DELETE CASCADE,
  display_type TEXT NOT NULL CHECK (display_type IN ('trophyIcon', 'gameCover', 'figurine', 'custom')),
  shelf_number INTEGER NOT NULL CHECK (shelf_number >= 0),
  position_in_shelf INTEGER NOT NULL CHECK (position_in_shelf >= 0 AND position_in_shelf < 10),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure user can't have duplicate trophies in display
  UNIQUE(user_id, trophy_id),
  
  -- Ensure no overlapping positions (one item per slot)
  UNIQUE(user_id, shelf_number, position_in_shelf)
);

-- Index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_display_case_items_user 
  ON display_case_items(user_id);

-- Index for position queries
CREATE INDEX IF NOT EXISTS idx_display_case_items_position 
  ON display_case_items(user_id, shelf_number, position_in_shelf);

-- Enable RLS
ALTER TABLE display_case_items ENABLE ROW LEVEL SECURITY;

-- Users can only see/modify their own display items
CREATE POLICY display_case_items_user_policy 
  ON display_case_items 
  FOR ALL 
  USING (auth.uid() = user_id);

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_display_case_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_display_case_items_updated_at
  BEFORE UPDATE ON display_case_items
  FOR EACH ROW
  EXECUTE FUNCTION update_display_case_items_updated_at();

-- Comments
COMMENT ON TABLE display_case_items IS 'User-customized trophy display case arrangements';
COMMENT ON COLUMN display_case_items.display_type IS 'How the trophy is displayed: trophyIcon, gameCover, figurine, or custom';
COMMENT ON COLUMN display_case_items.shelf_number IS 'Which shelf (0-indexed from top)';
COMMENT ON COLUMN display_case_items.position_in_shelf IS 'Position on shelf (0-indexed from left)';
