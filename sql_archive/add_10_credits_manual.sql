-- Manually add the 10 credits from the first test purchase
-- This compensates for the webhook using the wrong function before the fix

INSERT INTO user_ai_credits (
  user_id,
  pack_credits,
  created_at,
  updated_at
)
SELECT 
  id,
  10,
  NOW(),
  NOW()
FROM auth.users
WHERE email = 'mdorminey79@gmail.com'
ON CONFLICT (user_id) 
DO UPDATE SET
  pack_credits = user_ai_credits.pack_credits + 10,
  updated_at = NOW();

-- Verify the credits were added
SELECT 
  u.email,
  uac.pack_credits
FROM auth.users u
LEFT JOIN user_ai_credits uac ON uac.user_id = u.id
WHERE u.email = 'mdorminey79@gmail.com';
