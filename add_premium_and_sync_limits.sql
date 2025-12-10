-- Add premium status and sync tracking tables

-- Add premium column to users (using auth.users metadata or custom table)
-- We'll track this in a separate table to avoid modifying Supabase auth.users
CREATE TABLE IF NOT EXISTS user_premium_status (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_premium BOOLEAN DEFAULT FALSE,
  premium_since TIMESTAMPTZ,
  premium_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add index for quick premium lookups
CREATE INDEX IF NOT EXISTS idx_user_premium_status_user_id ON user_premium_status(user_id);

-- Track sync history for rate limiting
CREATE TABLE IF NOT EXISTS user_sync_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform VARCHAR(20) NOT NULL, -- 'psn', 'xbox', 'steam'
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  success BOOLEAN DEFAULT TRUE
);

-- Add indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_user_sync_history_user_platform 
ON user_sync_history(user_id, platform, synced_at DESC);

-- Create view for easy sync limit checking
CREATE OR REPLACE VIEW user_sync_status AS
SELECT 
  u.id as user_id,
  ups.is_premium,
  -- PSN sync info
  (
    SELECT COUNT(*) 
    FROM user_sync_history ush 
    WHERE ush.user_id = u.id 
      AND ush.platform = 'psn' 
      AND ush.synced_at > NOW() - INTERVAL '24 hours'
      AND ush.success = true
  ) as psn_syncs_today,
  (
    SELECT MAX(synced_at) 
    FROM user_sync_history ush 
    WHERE ush.user_id = u.id 
      AND ush.platform = 'psn'
      AND ush.success = true
  ) as psn_last_sync,
  -- Xbox sync info
  (
    SELECT MAX(synced_at) 
    FROM user_sync_history ush 
    WHERE ush.user_id = u.id 
      AND ush.platform = 'xbox'
      AND ush.success = true
  ) as xbox_last_sync,
  -- Steam sync info
  (
    SELECT MAX(synced_at) 
    FROM user_sync_history ush 
    WHERE ush.user_id = u.id 
      AND ush.platform = 'steam'
      AND ush.success = true
  ) as steam_last_sync
FROM auth.users u
LEFT JOIN user_premium_status ups ON ups.user_id = u.id;

-- Function to check if user can sync
CREATE OR REPLACE FUNCTION can_user_sync(
  p_user_id UUID,
  p_platform VARCHAR(20)
) RETURNS JSON AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_last_sync TIMESTAMPTZ;
  v_psn_syncs_today INTEGER;
  v_can_sync BOOLEAN := false;
  v_reason TEXT := '';
  v_wait_seconds INTEGER := 0;
BEGIN
  -- Get user premium status
  SELECT COALESCE(is_premium, false) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- Get last sync time
  SELECT MAX(synced_at) INTO v_last_sync
  FROM user_sync_history
  WHERE user_id = p_user_id 
    AND platform = p_platform
    AND success = true;

  -- PSN specific checks
  IF p_platform = 'psn' THEN
    -- Count today's PSN syncs
    SELECT COUNT(*) INTO v_psn_syncs_today
    FROM user_sync_history
    WHERE user_id = p_user_id 
      AND platform = 'psn'
      AND synced_at > NOW() - INTERVAL '24 hours'
      AND success = true;

    -- Check daily limit
    IF v_is_premium THEN
      IF v_psn_syncs_today >= 12 THEN
        v_can_sync := false;
        v_reason := 'Daily limit reached (12/12)';
        RETURN json_build_object('can_sync', v_can_sync, 'reason', v_reason);
      END IF;
    ELSE
      IF v_psn_syncs_today >= 3 THEN
        v_can_sync := false;
        v_reason := 'Daily limit reached (3/3)';
        RETURN json_build_object('can_sync', v_can_sync, 'reason', v_reason);
      END IF;
    END IF;

    -- Check cooldown
    IF v_last_sync IS NOT NULL THEN
      IF v_is_premium THEN
        -- 30 minute cooldown for premium
        IF v_last_sync > NOW() - INTERVAL '30 minutes' THEN
          v_wait_seconds := EXTRACT(EPOCH FROM (v_last_sync + INTERVAL '30 minutes' - NOW()))::INTEGER;
          v_reason := 'Wait ' || v_wait_seconds || ' seconds (30 min cooldown)';
          RETURN json_build_object('can_sync', false, 'reason', v_reason, 'wait_seconds', v_wait_seconds);
        END IF;
      ELSE
        -- 2 hour cooldown for free
        IF v_last_sync > NOW() - INTERVAL '2 hours' THEN
          v_wait_seconds := EXTRACT(EPOCH FROM (v_last_sync + INTERVAL '2 hours' - NOW()))::INTEGER;
          v_reason := 'Wait ' || v_wait_seconds || ' seconds (2 hour cooldown)';
          RETURN json_build_object('can_sync', false, 'reason', v_reason, 'wait_seconds', v_wait_seconds);
        END IF;
      END IF;
    END IF;
  END IF;

  -- Xbox/Steam cooldown checks
  IF p_platform IN ('xbox', 'steam') THEN
    IF v_last_sync IS NOT NULL THEN
      IF v_is_premium THEN
        -- 15 minute cooldown for premium
        IF v_last_sync > NOW() - INTERVAL '15 minutes' THEN
          v_wait_seconds := EXTRACT(EPOCH FROM (v_last_sync + INTERVAL '15 minutes' - NOW()))::INTEGER;
          v_reason := 'Wait ' || v_wait_seconds || ' seconds (15 min cooldown)';
          RETURN json_build_object('can_sync', false, 'reason', v_reason, 'wait_seconds', v_wait_seconds);
        END IF;
      ELSE
        -- 1 hour cooldown for free
        IF v_last_sync > NOW() - INTERVAL '1 hour' THEN
          v_wait_seconds := EXTRACT(EPOCH FROM (v_last_sync + INTERVAL '1 hour' - NOW()))::INTEGER;
          v_reason := 'Wait ' || v_wait_seconds || ' seconds (1 hour cooldown)';
          RETURN json_build_object('can_sync', false, 'reason', v_reason, 'wait_seconds', v_wait_seconds);
        END IF;
      END IF;
    END IF;
  END IF;

  -- All checks passed
  v_can_sync := true;
  RETURN json_build_object('can_sync', v_can_sync, 'reason', 'OK');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments
COMMENT ON TABLE user_premium_status IS 'Tracks user premium subscription status';
COMMENT ON TABLE user_sync_history IS 'Tracks sync operations for rate limiting';
COMMENT ON FUNCTION can_user_sync IS 'Checks if user can sync based on premium status and rate limits';
