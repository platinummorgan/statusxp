-- Complete cleanup: Remove Yahoo email and make Apple the only identity

-- Step 1: Delete the email identity completely
DELETE FROM auth.identities
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
AND provider = 'email';

-- Step 2: Update raw_app_meta_data to make Apple the primary and only provider
UPDATE auth.users
SET raw_app_meta_data = jsonb_build_object(
    'provider', 'apple',
    'providers', jsonb_build_array('apple')
)
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 3: Verify - should only show Apple identity now
SELECT 
    u.id,
    u.email,
    u.raw_app_meta_data,
    i.provider,
    i.provider_id
FROM auth.users u
LEFT JOIN auth.identities i ON i.user_id = u.id
WHERE u.id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Step 4: Verify app_meta_data structure
SELECT 
    id,
    email,
    raw_app_meta_data->'provider' as primary_provider,
    raw_app_meta_data->'providers' as all_providers
FROM auth.users
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';
