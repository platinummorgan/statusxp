-- Check if xdoscbobbles exists in auth.users
SELECT 
    id,
    email,
    raw_user_meta_data->>'display_name' as display_name,
    created_at,
    confirmed_at
FROM auth.users
WHERE email ILIKE '%xdoscbobbles%' 
   OR raw_user_meta_data->>'display_name' ILIKE '%xdoscbobbles%';
