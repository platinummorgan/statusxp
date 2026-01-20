-- Fix: Update raw_app_meta_data to make Apple the primary provider

UPDATE auth.users
SET raw_app_meta_data = jsonb_set(
    raw_app_meta_data,
    '{provider}',
    '"apple"'
)
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Verify the fix
SELECT 
    id,
    email,
    raw_app_meta_data
FROM auth.users
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';
