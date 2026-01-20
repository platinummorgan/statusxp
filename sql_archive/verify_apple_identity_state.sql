-- Verify current Apple identity state for debugging
SELECT 
    u.id,
    u.email,
    u.email_confirmed_at,
    u.created_at as user_created,
    u.last_sign_in_at,
    u.raw_user_meta_data,
    i.provider,
    i.provider_id,
    i.identity_data,
    i.created_at as identity_created,
    i.last_sign_in_at as identity_last_signin
FROM auth.users u
JOIN auth.identities i ON i.user_id = u.id
WHERE u.id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
ORDER BY i.provider;

-- Check for any sessions that might be cached
SELECT 
    id,
    user_id,
    created_at,
    updated_at,
    aal,
    NOT AFTER expires_at < NOW() as is_expired
FROM auth.sessions
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
ORDER BY created_at DESC;
