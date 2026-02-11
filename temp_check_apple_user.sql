-- Check user profile and premium status for Apple validation issue
-- User ID: a6deaf66-244f-4c8d-bef5-e3e1184370b7

-- 1. Check if user exists in profiles
SELECT 
  id,
  username,
  display_name,
  created_at,
  merged_into_user_id
FROM profiles
WHERE id = 'a6deaf66-244f-4c8d-bef5-e3e1184370b7';

-- 2. Check premium status
SELECT 
  user_id,
  is_premium,
  premium_source,
  premium_expires_at,
  premium_since,
  created_at,
  updated_at
FROM user_premium_status
WHERE user_id = 'a6deaf66-244f-4c8d-bef5-e3e1184370b7';

-- 3. Check auth.users table (email might be there)
SELECT 
  id,
  email,
  created_at,
  confirmed_at,
  deleted_at
FROM auth.users
WHERE id = 'a6deaf66-244f-4c8d-bef5-e3e1184370b7';
