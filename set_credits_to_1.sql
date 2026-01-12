-- Set credits to exactly 1 for testing
UPDATE user_ai_credits 
SET pack_credits = 1, 
    updated_at = NOW()
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');

-- Verify
SELECT pack_credits FROM user_ai_credits 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');
