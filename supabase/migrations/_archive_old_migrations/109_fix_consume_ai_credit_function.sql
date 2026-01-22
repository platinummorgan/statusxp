-- Fix consume_ai_credit to handle source column and prevent duplicates
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

  -- Premium users: unlimited, just log usage
  IF v_is_premium THEN
    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today, source)
    VALUES (p_user_id, CURRENT_DATE, 1, 'premium')
    ON CONFLICT (user_id, usage_date) 
    DO UPDATE SET 
      uses_today = user_ai_daily_usage.uses_today + 1,
      source = 'premium';
    
    RETURN json_build_object('success', TRUE, 'source', 'premium');
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

    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today, source)
    VALUES (p_user_id, CURRENT_DATE, 1, 'pack')
    ON CONFLICT (user_id, usage_date) 
    DO UPDATE SET 
      uses_today = user_ai_daily_usage.uses_today + 1,
      source = 'pack';

    RETURN json_build_object('success', TRUE, 'source', 'pack');
  END IF;

  -- Check daily free usage
  SELECT COALESCE(uses_today, 0) INTO v_uses_today
  FROM user_ai_daily_usage
  WHERE user_id = p_user_id
    AND usage_date = CURRENT_DATE;

  v_uses_today := COALESCE(v_uses_today, 0);

  -- Use daily free if available
  IF v_uses_today < v_daily_free_limit THEN
    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today, source)
    VALUES (p_user_id, CURRENT_DATE, 1, 'daily_free')
    ON CONFLICT (user_id, usage_date) 
    DO UPDATE SET uses_today = user_ai_daily_usage.uses_today + 1;

    RETURN json_build_object('success', TRUE, 'source', 'daily_free');
  END IF;

  -- No credits available
  RETURN json_build_object('success', FALSE, 'error', 'No AI credits available');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
