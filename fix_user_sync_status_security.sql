-- Fix security_definer warning for user_sync_status view
-- This removes SECURITY DEFINER and uses SECURITY INVOKER instead
-- The view will run with the permissions of the querying user (RLS enforced)

-- Drop and recreate the view without SECURITY DEFINER
DROP VIEW IF EXISTS user_sync_status;

CREATE VIEW user_sync_status 
WITH (security_invoker = true)
AS
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

-- Grant permissions
GRANT SELECT ON user_sync_status TO authenticated;

-- Add comment
COMMENT ON VIEW user_sync_status IS 'Secure view of user sync status - uses security_invoker to enforce RLS';
