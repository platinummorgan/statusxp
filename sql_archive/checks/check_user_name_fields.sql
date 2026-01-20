-- Check user profile and metadata for name fields

-- Check profiles table
SELECT 
    id,
    username,
    display_name,
    avatar_url,
    created_at
FROM profiles
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Check auth.users metadata
SELECT 
    id,
    email,
    raw_user_meta_data,
    raw_app_meta_data
FROM auth.users
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Check if there's a full_name or name field that got nulled
SELECT 
    id,
    email,
    raw_user_meta_data->>'full_name' as full_name,
    raw_user_meta_data->>'name' as name,
    raw_user_meta_data->>'email' as meta_email
FROM auth.users
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';
