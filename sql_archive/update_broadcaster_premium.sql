-- Update broadcaster premium to non-Twitch source
-- This protects your premium from being modified by Twitch subscription logic

UPDATE user_premium_status
SET 
    premium_source = 'internal',  -- or 'stripe' if you have a Stripe subscription
    premium_expires_at = '2030-12-31 23:59:59'::timestamp
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';  -- mdorminey79@gmail.com

-- Verify the update
SELECT 
    id, 
    is_premium, 
    premium_source, 
    premium_expires_at,
    premium_since
FROM user_premium_status
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
