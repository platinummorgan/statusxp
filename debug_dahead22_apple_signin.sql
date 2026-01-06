-- Debug DaHead22 Apple Sign-In Issue
-- Problem: User gets "already connected to another account" error when trying to sign in with Apple

-- Step 1: Find DaHead22's user record
SELECT 
    id as user_id,
    username,
    psn_online_id,
    created_at,
    updated_at
FROM profiles
WHERE LOWER(username) = 'dahead22';

-- Step 2: Check auth.users table for DaHead22
-- Note: This requires service_role access or Supabase Dashboard
-- You'll need to run this in Supabase Dashboard SQL Editor with service_role
-- SELECT 
--     id,
--     email,
--     created_at,
--     last_sign_in_at,
--     raw_app_meta_data,
--     raw_user_meta_data
-- FROM auth.users
-- WHERE id = (SELECT id FROM profiles WHERE LOWER(username) = 'dahead22');

-- Step 3: Check auth.identities table for linked providers
-- Note: This requires service_role access or Supabase Dashboard
-- SELECT 
--     id,
--     user_id,
--     identity_data,
--     provider,
--     created_at,
--     updated_at
-- FROM auth.identities
-- WHERE user_id = (SELECT id FROM profiles WHERE LOWER(username) = 'dahead22');

-- Explanation of the problem:
-- When the user logs out and tries to sign back in with Apple, the app calls
-- signInWithIdToken() because currentUser is null after logout.
-- 
-- However, Supabase sees that this Apple ID is already linked to a different
-- auth.users account (possibly created with email/password first).
-- 
-- The fix is to detect this scenario and use the correct sign-in method.
-- OR the user may have duplicate accounts that need merging.
