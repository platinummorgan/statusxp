-- Create can_user_sync function
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
DECLARE
  user_id UUID;
  last_sync TIMESTAMPTZ;
  cooldown_minutes INTEGER := 5; -- 5 minute cooldown between syncs
  time_since_last INTEGER;
BEGIN
  -- Get current user ID from JWT
  user_id := auth.uid();
  
  IF user_id IS NULL THEN
    RETURN QUERY SELECT false, 'Not authenticated', NULL::timestamptz, 0;
    RETURN;
  END IF;
  
  -- Get last sync time based on platform
  IF platform_name = 'steam' THEN
    SELECT last_steam_sync_at INTO last_sync 
    FROM profiles 
    WHERE id = user_id;
  ELSIF platform_name = 'psn' THEN
    SELECT last_psn_sync_at INTO last_sync 
    FROM profiles 
    WHERE id = user_id;
  ELSIF platform_name = 'xbox' THEN
    SELECT last_xbox_sync_at INTO last_sync 
    FROM profiles 
    WHERE id = user_id;
  ELSE
    RETURN QUERY SELECT false, 'Invalid platform', NULL::timestamptz, 0;
    RETURN;
  END IF;
  
  -- If no previous sync, allow immediately
  IF last_sync IS NULL THEN
    RETURN QUERY SELECT true, 'No previous sync', NULL::timestamptz, 0;
    RETURN;
  END IF;
  
  -- Calculate time since last sync in seconds
  time_since_last := EXTRACT(EPOCH FROM (NOW() - last_sync))::INTEGER;
  
  -- Check cooldown (5 minutes = 300 seconds)
  IF time_since_last < (cooldown_minutes * 60) THEN
    RETURN QUERY SELECT 
      false, 
      'Cooldown period active',
      last_sync,
      (cooldown_minutes * 60) - time_since_last;
  ELSE
    RETURN QUERY SELECT 
      true, 
      'Ready to sync',
      last_sync,
      0;
  END IF;
END;
$$;