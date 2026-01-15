-- Create atomic unlock achievement function
-- This prevents race conditions by doing check+insert in a single transaction

CREATE OR REPLACE FUNCTION unlock_achievement_if_new(
  p_user_id UUID,
  p_achievement_id TEXT,
  p_unlocked_at TIMESTAMPTZ DEFAULT NOW()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  -- Try to insert, ignore if already exists
  INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
  VALUES (p_user_id, p_achievement_id, p_unlocked_at)
  ON CONFLICT (user_id, achievement_id) DO NOTHING;
  
  -- Return true if a row was inserted, false if it already existed
  RETURN FOUND;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION unlock_achievement_if_new TO authenticated;
