-- Migration: Add Premium Status and Sync Rate Limiting
-- Purpose: Track premium subscriptions and enforce platform sync rate limits

-- 1. Create user_premium_status table
CREATE TABLE IF NOT EXISTS user_premium_status (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_premium BOOLEAN DEFAULT FALSE,
  premium_since TIMESTAMPTZ,
  premium_expires_at TIMESTAMPTZ,
  subscription_id TEXT, -- Store Google Play/Apple subscription ID
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_premium_status ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own premium status"
  ON user_premium_status FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own premium status"
  ON user_premium_status FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own premium status"
  ON user_premium_status FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 2. Create user_sync_history table
CREATE TABLE IF NOT EXISTS user_sync_history (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('psn', 'xbox', 'steam')),
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  success BOOLEAN DEFAULT TRUE,
  error_message TEXT
);

-- Enable RLS
ALTER TABLE user_sync_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own sync history"
  ON user_sync_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own sync history"
  ON user_sync_history FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_sync_history_user_platform_date 
  ON user_sync_history(user_id, platform, synced_at DESC);

-- 3. Create view for current sync status
CREATE OR REPLACE VIEW user_sync_status AS
SELECT 
  ush.user_id,
  ush.platform,
  COUNT(*) FILTER (WHERE ush.synced_at::DATE = CURRENT_DATE) as syncs_today,
  MAX(ush.synced_at) as last_sync_at,
  ups.is_premium
FROM user_sync_history ush
LEFT JOIN user_premium_status ups ON ups.user_id = ush.user_id
WHERE ush.success = TRUE
GROUP BY ush.user_id, ush.platform, ups.is_premium;

-- 4. Create function to check if user can sync
CREATE OR REPLACE FUNCTION can_user_sync(p_user_id UUID, p_platform TEXT)
RETURNS JSON AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_syncs_today INTEGER;
  v_last_sync_at TIMESTAMPTZ;
  v_cooldown_minutes INTEGER;
  v_daily_limit INTEGER;
  v_wait_seconds INTEGER;
BEGIN
  -- Get premium status
  SELECT COALESCE(is_premium, FALSE) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- Get sync stats for today
  SELECT 
    COALESCE(COUNT(*) FILTER (WHERE synced_at::DATE = CURRENT_DATE), 0),
    MAX(synced_at)
  INTO v_syncs_today, v_last_sync_at
  FROM user_sync_history
  WHERE user_id = p_user_id 
    AND platform = p_platform
    AND success = TRUE;

  -- Set limits based on platform and premium status
  IF p_platform = 'psn' THEN
    IF v_is_premium THEN
      v_cooldown_minutes := 30;  -- 30 min cooldown for premium
      v_daily_limit := 12;       -- 12 syncs/day for premium
    ELSE
      v_cooldown_minutes := 120; -- 2 hour cooldown for free
      v_daily_limit := 3;        -- 3 syncs/day for free
    END IF;
  ELSE -- Xbox or Steam
    IF v_is_premium THEN
      v_cooldown_minutes := 15;  -- 15 min cooldown for premium
      v_daily_limit := 999;      -- Unlimited for premium
    ELSE
      v_cooldown_minutes := 60;  -- 1 hour cooldown for free
      v_daily_limit := 999;      -- Unlimited for free (just cooldown)
    END IF;
  END IF;

  -- Check daily limit
  IF v_syncs_today >= v_daily_limit THEN
    RETURN json_build_object(
      'can_sync', FALSE,
      'reason', format('Daily limit reached (%s/%s)', v_syncs_today, v_daily_limit),
      'wait_seconds', 0
    );
  END IF;

  -- Check cooldown
  IF v_last_sync_at IS NOT NULL THEN
    v_wait_seconds := GREATEST(0, 
      v_cooldown_minutes * 60 - EXTRACT(EPOCH FROM (NOW() - v_last_sync_at))::INTEGER
    );
    
    IF v_wait_seconds > 0 THEN
      RETURN json_build_object(
        'can_sync', FALSE,
        'reason', 'Cooldown active',
        'wait_seconds', v_wait_seconds
      );
    END IF;
  END IF;

  -- Can sync!
  RETURN json_build_object(
    'can_sync', TRUE,
    'reason', NULL,
    'wait_seconds', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION can_user_sync TO authenticated;

-- 5. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_premium_status_user 
  ON user_premium_status(user_id);

CREATE INDEX IF NOT EXISTS idx_sync_history_recent 
  ON user_sync_history(user_id, platform, synced_at DESC)
  WHERE synced_at >= CURRENT_DATE - INTERVAL '7 days';
