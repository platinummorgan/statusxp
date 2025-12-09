-- Reset password for your user account
-- Run this in Supabase SQL Editor

-- Update the password directly in the auth schema
UPDATE auth.users
SET encrypted_password = crypt('Mich@3l9', gen_salt('bf'))
WHERE email = 'mdorminey79@gmail.com';

-- Verify it worked
SELECT email, created_at, last_sign_in_at 
FROM auth.users 
WHERE email = 'mdorminey79@gmail.com';

