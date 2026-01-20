SELECT user_id, monthly_ai_credits, is_premium 
FROM user_premium_status 
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');
