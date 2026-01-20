-- Add 2 credits manually for testing
UPDATE user_ai_credits 
SET pack_credits = pack_credits + 2, 
    updated_at = NOW()
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');

-- Verify
SELECT pack_credits FROM user_ai_credits 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');
