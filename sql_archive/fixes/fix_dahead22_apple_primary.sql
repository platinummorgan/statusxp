-- Fix DaHead22's Apple ID to be the primary sign-in method
-- This unlinks Apple from the email account and makes Apple standalone

-- Step 1: Verify current setup
SELECT 
    u.id,
    u.email,
    i.provider,
    i.provider_id,
    i.identity_data->>'email' as identity_email
FROM auth.users u
JOIN auth.identities i ON i.user_id = u.id
WHERE u.id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
ORDER BY i.created_at;

-- Step 2: Delete the Apple identity link
-- This unlinks Apple from the account
DELETE FROM auth.identities
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
AND provider = 'apple';

-- Step 3: Verify Apple is unlinked
SELECT 
    u.id,
    u.email,
    i.provider,
    i.provider_id
FROM auth.users u
LEFT JOIN auth.identities i ON i.user_id = u.id
WHERE u.id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- ALTERNATIVE: Make Apple the primary by updating user email
-- This keeps the same account but changes primary identity to Apple

-- Update user's primary email to Apple email
UPDATE auth.users
SET 
    email = 'qyvpfqy4wq@privaterelay.appleid.com',
    email_confirmed_at = NOW(),
    raw_user_meta_data = jsonb_set(
        raw_user_meta_data,
        '{email}',
        '"qyvpfqy4wq@privaterelay.appleid.com"'
    )
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Update the email identity to match
UPDATE auth.identities
SET identity_data = jsonb_set(
    identity_data,
    '{email}',
    '"qyvpfqy4wq@privaterelay.appleid.com"'
)
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
AND provider = 'email';

-- Verify
SELECT 
    u.email,
    i.provider,
    i.identity_data->>'email' as identity_email
FROM auth.users u
JOIN auth.identities i ON i.user_id = u.id
WHERE u.id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Now Apple Sign-In should work as the primary method!
