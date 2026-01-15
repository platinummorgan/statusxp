-- Create atomic unlock achievement function
-- This prevents race conditions by doing check+insert in a single transaction

CREATE OR REPLACE FUNCTION unlock_achievement_if_new(
  p_user_id UUID,
  p_achievement_id TEXT,
  p_unlocked_at TIMESTAMPTZ DEFAULT NOW()
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- Check if achievement already exists
  SELECT EXISTS(
    SELECT 1 FROM user_meta_achievements 
    WHERE user_id = p_user_id AND achievement_id = p_achievement_id
  ) INTO v_exists;
  
  -- If it doesn't exist, insert it
  IF NOT v_exists THEN
    INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
    VALUES (p_user_id, p_achievement_id, p_unlocked_at);
    RETURN TRUE;
  END IF;
  
  -- Already exists, return false
  RETURN FALSE;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION unlock_achievement_if_new TO authenticated;
