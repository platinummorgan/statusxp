-- Check Apple identity linkage for DaHead22 / djheygood

-- Check all identities for this user
SELECT 
    id,
    email,
    raw_user_meta_data->>'email' as metadata_email,
    raw_user_meta_data->>'provider' as provider,
    created_at,
    last_sign_in_at
FROM auth.users
WHERE email IN ('djheygood@yahoo.com', 'qyvpfqy4wq@privaterelay.appleid.com')
ORDER BY created_at;

-- Check identity providers linked to these users
SELECT 
    u.id as user_id,
    u.email,
    i.provider,
    i.provider_id,
    i.identity_data->>'email' as identity_email,
    i.created_at
FROM auth.users u
JOIN auth.identities i ON i.user_id = u.id
WHERE u.email IN ('djheygood@yahoo.com', 'qyvpfqy4wq@privaterelay.appleid.com')
ORDER BY u.created_at, i.created_at;

-- Find if there are duplicate Apple identity links
SELECT 
    provider_id,
    provider,
    COUNT(*) as link_count,
    string_agg(user_id::text, ', ') as user_ids
FROM auth.identities
WHERE provider = 'apple'
GROUP BY provider_id, provider
HAVING COUNT(*) > 1;
