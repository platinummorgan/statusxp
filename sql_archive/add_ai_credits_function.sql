-- Function to add AI credits to a user's balance
-- This is called by the Stripe webhook when an AI pack is purchased

CREATE OR REPLACE FUNCTION add_ai_credits(
  p_user_id uuid,
  p_credits integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Insert or update user_premium_status with additional credits
  INSERT INTO user_premium_status (
    user_id,
    monthly_ai_credits,
    created_at,
    updated_at
  )
  VALUES (
    p_user_id,
    p_credits,
    now(),
    now()
  )
  ON CONFLICT (user_id) 
  DO UPDATE SET
    monthly_ai_credits = user_premium_status.monthly_ai_credits + p_credits,
    updated_at = now();
END;
$$;
