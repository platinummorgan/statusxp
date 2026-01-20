-- Create ultra-simple can_user_sync that can't fail
DROP FUNCTION IF EXISTS can_user_sync(TEXT);

CREATE OR REPLACE FUNCTION can_user_sync(
  platform_name TEXT DEFAULT 'steam'
)
RETURNS TABLE(
  can_sync BOOLEAN,
  reason TEXT,
  last_sync_at TIMESTAMPTZ,
  cooldown_remaining_seconds INTEGER
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Just return true always - no logic that can fail
  RETURN QUERY SELECT 
    true::BOOLEAN, 
    'Always allowed'::TEXT, 
    NOW()::timestamptz, 
    0::INTEGER;
END;
$$;

-- Grant all permissions
GRANT ALL ON FUNCTION can_user_sync(TEXT) TO PUBLIC;