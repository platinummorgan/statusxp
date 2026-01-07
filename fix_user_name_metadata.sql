-- Add name to metadata so Apple Sign-In shows proper name

UPDATE auth.users
SET raw_user_meta_data = jsonb_set(
    jsonb_set(
        raw_user_meta_data,
        '{full_name}',
        '"djheygood"'
    ),
    '{name}',
    '"djheygood"'
)
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Verify
SELECT 
    id,
    email,
    raw_user_meta_data->>'full_name' as full_name,
    raw_user_meta_data->>'name' as name
FROM auth.users
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';
