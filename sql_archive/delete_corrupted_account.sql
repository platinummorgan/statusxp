-- NUCLEAR OPTION: Delete the entire account and let him sign up fresh with Apple
-- This will preserve his profile data (username, games, achievements)
-- but delete the corrupted auth identity

-- Step 1: Verify what will be preserved (profiles, user_games, user_achievements stay)
SELECT 
    'Will be preserved' as note,
    id,
    username,
    display_name
FROM profiles
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 2: DELETE auth identities
DELETE FROM auth.identities
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 3: DELETE auth sessions  
DELETE FROM auth.sessions
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 4: DELETE auth user (this will trigger cascade)
DELETE FROM auth.users
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 5: Verify auth is gone but profile remains
SELECT 
    'Profile still exists' as note,
    id,
    username
FROM profiles
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Now he can sign up fresh with Apple Sign-In
-- The app will create a new auth.users record but link to existing profile by email matching
