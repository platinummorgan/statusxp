-- Fix corrupted user profile with NULL display names
-- This happens when Apple Sign-in linking fails or creates duplicate accounts

-- Step 1: Identify the problematic user
-- Run this first to find the user:
SELECT 
  p.id,
  au.email,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name,
  au.raw_user_meta_data,
  au.raw_app_meta_data
FROM profiles p
JOIN auth.users au ON au.id = p.id
WHERE 
  p.psn_online_id IS NULL 
  AND p.xbox_gamertag IS NULL 
  AND p.steam_display_name IS NULL
  AND au.email IS NOT NULL;

-- Step 2: Fix the profile by setting a default display name from email
-- Replace 'USER_ID_HERE' with the actual user ID from Step 1
/*
UPDATE profiles
SET 
  -- Use email username as fallback display name
  psn_online_id = COALESCE(psn_online_id, SPLIT_PART((SELECT email FROM auth.users WHERE id = 'USER_ID_HERE'), '@', 1)),
  updated_at = NOW()
WHERE id = 'USER_ID_HERE';
*/

-- Step 3: If user has duplicate accounts, merge them
-- Check for duplicates by email:
SELECT 
  au.id,
  au.email,
  au.created_at,
  au.raw_app_meta_data->>'provider' as provider,
  p.psn_online_id,
  p.xbox_gamertag,
  p.steam_display_name
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
WHERE LOWER(au.email) IN (
  SELECT LOWER(email)
  FROM auth.users
  WHERE email IS NOT NULL
  GROUP BY LOWER(email)
  HAVING COUNT(*) > 1
)
ORDER BY au.email, au.created_at;

-- Step 4: Merge duplicate accounts (CAREFUL - TEST FIRST)
-- Keep the older account, transfer data from newer account
-- See merge_dahead22_accounts.sql for template
