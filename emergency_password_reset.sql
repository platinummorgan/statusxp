-- Emergency password reset for ojjm11@outlook.com
-- Sets password to: TempPass2026!
-- User can then sign in and change it in settings

-- NOTE: You need to run this through Supabase Dashboard SQL Editor
-- because it requires admin access

SELECT auth.update_user(
  'b23e206a-02d1-4920-b1ee-61ee44583518',
  '{"password": "TempPass2026!"}'
);

-- Verify the result (should show user info)
SELECT 
  id,
  email,
  created_at,
  last_sign_in_at
FROM auth.users
WHERE id = 'b23e206a-02d1-4920-b1ee-61ee44583518';
