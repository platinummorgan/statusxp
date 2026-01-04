-- Migration: Track unlinked gaming platforms to prevent immediate re-linking to different accounts
-- Prevents users from unlinking Xbox/PSN/Steam and immediately linking to a new account

CREATE TABLE IF NOT EXISTS platform_link_history (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform TEXT NOT NULL CHECK (platform IN ('psn', 'xbox', 'steam')),
  platform_identifier TEXT NOT NULL, -- psn_account_id, xbox_xuid, or steam_id
  platform_username TEXT, -- psn_online_id, xbox_gamertag, or steam_display_name
  linked_at TIMESTAMPTZ NOT NULL,
  unlinked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_platform_link_history_identifier ON platform_link_history(platform, platform_identifier);
CREATE INDEX idx_platform_link_history_user ON platform_link_history(user_id);
CREATE INDEX idx_platform_link_history_unlinked ON platform_link_history(unlinked_at);

COMMENT ON TABLE platform_link_history IS 
  'Tracks unlinked gaming platforms to prevent users from immediately re-linking to different accounts';

-- Function to check history before allowing link
CREATE OR REPLACE FUNCTION check_platform_link_history(
  p_current_user_id UUID,
  p_platform TEXT,
  p_identifier TEXT
) RETURNS TABLE (
  was_linked_before BOOLEAN,
  previous_user_id UUID,
  previous_email TEXT,
  unlinked_at TIMESTAMPTZ,
  days_since_unlink INTEGER
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT 
    TRUE as was_linked_before,
    plh.user_id as previous_user_id,
    au.email as previous_email,
    plh.unlinked_at,
    EXTRACT(DAY FROM NOW() - plh.unlinked_at)::INTEGER as days_since_unlink
  FROM platform_link_history plh
  JOIN auth.users au ON au.id = plh.user_id
  WHERE plh.platform = p_platform
    AND plh.platform_identifier = p_identifier
    AND plh.user_id != p_current_user_id
    AND plh.unlinked_at > NOW() - INTERVAL '30 days' -- Only check last 30 days
  ORDER BY plh.unlinked_at DESC
  LIMIT 1;
END;
$$;

COMMENT ON FUNCTION check_platform_link_history IS 
  'Checks if a gaming platform was recently unlinked from a different account (within 30 days)';
