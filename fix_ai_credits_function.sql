-- Fix AI Credits Functions to work with existing schema
-- This will NOT alter any tables, just replace the functions

-- Drop old functions if they exist
DROP FUNCTION IF EXISTS can_use_ai(UUID);
DROP FUNCTION IF EXISTS consume_ai_credit(UUID);

-- Create can_use_ai function that works with existing schema
CREATE OR REPLACE FUNCTION can_use_ai(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_pack_credits INTEGER;
  v_uses_today INTEGER;
  v_daily_free_limit INTEGER := 3;
BEGIN
  -- Check if user is premium
  SELECT COALESCE(is_premium, FALSE) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- If premium, unlimited AI usage
  IF v_is_premium THEN
    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'premium',
      'remaining', -1,
      'pack_credits', 0,
      'daily_free', 0
    );
  END IF;

  -- Check pack credits
  SELECT COALESCE(pack_credits, 0) INTO v_pack_credits
  FROM user_ai_credits
  WHERE user_id = p_user_id;

  -- If user has pack credits, use those
  IF v_pack_credits > 0 THEN
    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'pack',
      'remaining', v_pack_credits,
      'pack_credits', v_pack_credits,
      'daily_free', 0
    );
  END IF;

  -- Check daily free usage (using existing schema)
  SELECT COALESCE(uses_today, 0) INTO v_uses_today
  FROM user_ai_daily_usage
  WHERE user_id = p_user_id
    AND usage_date = CURRENT_DATE;

  -- Default to 0 if no record exists
  v_uses_today := COALESCE(v_uses_today, 0);

  -- If user has daily free credits left
  IF v_uses_today < v_daily_free_limit THEN
    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'daily_free',
      'remaining', v_daily_free_limit - v_uses_today,
      'pack_credits', 0,
      'daily_free', v_daily_free_limit - v_uses_today
    );
  END IF;

  -- No credits available
  RETURN json_build_object(
    'can_use', FALSE,
    'source', 'none',
    'remaining', 0,
    'pack_credits', 0,
    'daily_free', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create consume_ai_credit function that works with existing schema
CREATE OR REPLACE FUNCTION consume_ai_credit(p_user_id UUID)
RETURNS JSON AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_pack_credits INTEGER;
  v_uses_today INTEGER;
  v_daily_free_limit INTEGER := 3;
BEGIN
  -- Check premium status
  SELECT COALESCE(is_premium, FALSE) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- Premium users: unlimited, just return success
  IF v_is_premium THEN
    -- Optionally log usage for analytics
    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today)
    VALUES (p_user_id, CURRENT_DATE, 1)
    ON CONFLICT (user_id, usage_date) 
    DO UPDATE SET uses_today = user_ai_daily_usage.uses_today + 1;
    
    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'premium',
      'remaining', -1,
      'pack_credits', 0,
      'daily_free', 0
    );
  END IF;

  -- Check pack credits
  SELECT COALESCE(pack_credits, 0) INTO v_pack_credits
  FROM user_ai_credits
  WHERE user_id = p_user_id;

  -- Use pack credit if available
  IF v_pack_credits > 0 THEN
    UPDATE user_ai_credits
    SET pack_credits = pack_credits - 1,
        updated_at = NOW()
    WHERE user_id = p_user_id;

    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'pack',
      'remaining', v_pack_credits - 1,
      'pack_credits', v_pack_credits - 1,
      'daily_free', 0
    );
  END IF;

  -- Check daily free usage
  SELECT COALESCE(uses_today, 0) INTO v_uses_today
  FROM user_ai_daily_usage
  WHERE user_id = p_user_id
    AND usage_date = CURRENT_DATE;

  v_uses_today := COALESCE(v_uses_today, 0);

  -- Use daily free if available
  IF v_uses_today < v_daily_free_limit THEN
    -- Insert or update daily usage
    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today)
    VALUES (p_user_id, CURRENT_DATE, 1)
    ON CONFLICT (user_id, usage_date)
    DO UPDATE SET uses_today = user_ai_daily_usage.uses_today + 1;

    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'daily_free',
      'remaining', v_daily_free_limit - v_uses_today - 1,
      'pack_credits', 0,
      'daily_free', v_daily_free_limit - v_uses_today - 1
    );
  END IF;

  -- No credits available
  RETURN json_build_object(
    'can_use', FALSE,
    'source', 'none',
    'remaining', 0,
    'pack_credits', 0,
    'daily_free', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION can_use_ai TO authenticated;
GRANT EXECUTE ON FUNCTION consume_ai_credit TO authenticated;

-- Add unique constraint if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'user_ai_daily_usage_user_id_usage_date_key'
    ) THEN
        ALTER TABLE user_ai_daily_usage 
        ADD CONSTRAINT user_ai_daily_usage_user_id_usage_date_key 
        UNIQUE (user_id, usage_date);
    END IF;
END $$;
