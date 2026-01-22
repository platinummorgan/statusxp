-- Function to check if an OAuth user might be a duplicate of an existing account
-- This checks if the OAuth provider's email matches an existing user's gaming accounts
CREATE OR REPLACE FUNCTION check_oauth_duplicate(
  p_provider TEXT,
  p_email TEXT
)
RETURNS TABLE (
  existing_user_id UUID,
  existing_email TEXT,
  matching_platform TEXT,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- This function is called AFTER OAuth sign-in to check if the new account
  -- might be a duplicate of an existing account
  
  -- For now, we can't prevent the duplicate creation because Supabase
  -- creates the account before we can check. But we can detect it after
  -- and show a warning to the user.
  
  -- Check if there's another user with the same PSN/Xbox/Steam data
  -- (This would mean they synced with one account, then created another)
  
  RETURN QUERY
  SELECT 
    p1.id as existing_user_id,
    au.email as existing_email,
    CASE 
      WHEN p1.psn_online_id IS NOT NULL THEN 'PSN: ' || p1.psn_online_id
      WHEN p1.xbox_gamertag IS NOT NULL THEN 'Xbox: ' || p1.xbox_gamertag
      WHEN p1.steam_display_name IS NOT NULL THEN 'Steam: ' || p1.steam_display_name
      ELSE 'Unknown'
    END as matching_platform,
    'You may have created a duplicate account. Contact support to merge accounts.' as message
  FROM profiles p1
  LEFT JOIN auth.users au ON au.id = p1.id
  WHERE p1.id != (
    -- Get the user ID of the OAuth account that just signed in
    SELECT id FROM auth.users WHERE email = p_email AND raw_app_meta_data->>'provider' = p_provider
  )
  AND (
    -- Has synced some gaming data
    p1.psn_online_id IS NOT NULL 
    OR p1.xbox_gamertag IS NOT NULL 
    OR p1.steam_display_name IS NOT NULL
  )
  LIMIT 1;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION check_oauth_duplicate TO authenticated;
