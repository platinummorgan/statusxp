-- COMPREHENSIVE APPLE OAUTH DIAGNOSTIC

-- 1. Check if Apple provider_id exists and which user it belongs to
SELECT 
    'Apple Provider Check' as check_type,
    user_id,
    provider,
    provider_id,
    identity_data
FROM auth.identities
WHERE provider_id = '000774.de2f22bf5d324830a60b580168c5117a.1557';

-- 2. Check ALL identities for this user
SELECT 
    'User Identities' as check_type,
    id as identity_id,
    user_id,
    provider,
    provider_id,
    identity_data,
    created_at,
    updated_at,
    last_sign_in_at
FROM auth.identities
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
ORDER BY provider;

-- 3. Check if there are any OTHER users with the same Apple private relay email
SELECT 
    'Duplicate Email Check' as check_type,
    id,
    email,
    created_at,
    email_confirmed_at
FROM auth.users
WHERE email = 'qyvpfqy4wq@privaterelay.appleid.com';

-- 4. Check if there are multiple Apple identities with same provider_id (shouldn't happen)
SELECT 
    'Duplicate Apple Provider' as check_type,
    user_id,
    provider_id,
    COUNT(*) as count
FROM auth.identities
WHERE provider = 'apple'
GROUP BY user_id, provider_id
HAVING COUNT(*) > 1;

-- 5. Full user record
SELECT 
    'User Record' as check_type,
    id,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at,
    last_sign_in_at,
    raw_user_meta_data,
    raw_app_meta_data
FROM auth.users
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- 6. Check for any orphaned Apple identities (no matching user)
SELECT 
    'Orphaned Identities' as check_type,
    i.id,
    i.user_id,
    i.provider,
    i.provider_id
FROM auth.identities i
LEFT JOIN auth.users u ON u.id = i.user_id
WHERE u.id IS NULL
AND i.provider = 'apple';
