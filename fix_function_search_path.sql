-- Fix search_path security warnings for functions
-- Adding SET search_path prevents potential SQL injection attacks

-- 1. Fix can_use_ai function
CREATE OR REPLACE FUNCTION can_use_ai(p_user_id UUID)
RETURNS JSON 
SET search_path = public, pg_temp
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_pack_credits INTEGER;
  v_daily_free_used INTEGER;
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
      'daily_free_remaining', 0
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
      'daily_free_remaining', 0
    );
  END IF;

  -- Check daily free usage
  SELECT COALESCE(COUNT(*), 0) INTO v_daily_free_used
  FROM user_ai_daily_usage
  WHERE user_id = p_user_id
    AND used_at::DATE = CURRENT_DATE
    AND source = 'daily_free';

  -- Check if daily free limit reached
  IF v_daily_free_used >= v_daily_free_limit THEN
    RETURN json_build_object(
      'can_use', FALSE,
      'source', 'daily_free',
      'remaining', 0,
      'pack_credits', 0,
      'daily_free_remaining', 0
    );
  END IF;

  -- Can use daily free
  RETURN json_build_object(
    'can_use', TRUE,
    'source', 'daily_free',
    'remaining', v_daily_free_limit - v_daily_free_used,
    'pack_credits', 0,
    'daily_free_remaining', v_daily_free_limit - v_daily_free_used
  );
END;
$$;

-- 2. Fix consume_ai_credit function
CREATE OR REPLACE FUNCTION consume_ai_credit(p_user_id UUID)
RETURNS JSON
SET search_path = public, pg_temp
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_pack_credits INTEGER;
  v_daily_free_used INTEGER;
  v_daily_free_limit INTEGER := 3;
  v_source TEXT;
BEGIN
  -- Check premium status
  SELECT COALESCE(is_premium, FALSE) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- Premium users: unlimited, just log usage
  IF v_is_premium THEN
    INSERT INTO user_ai_daily_usage (user_id, source)
    VALUES (p_user_id, 'premium');
    
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

    INSERT INTO user_ai_daily_usage (user_id, source)
    VALUES (p_user_id, 'pack');

    RETURN json_build_object('success', TRUE, 'source', 'pack');
  END IF;

  -- Check daily free usage
  SELECT COALESCE(COUNT(*), 0) INTO v_daily_free_used
  FROM user_ai_daily_usage
  WHERE user_id = p_user_id
    AND used_at::DATE = CURRENT_DATE
    AND source = 'daily_free';

  -- Check if daily free limit reached
  IF v_daily_free_used >= v_daily_free_limit THEN
    RETURN json_build_object('success', FALSE, 'reason', 'Daily limit reached');
  END IF;

  -- Use daily free credit
  INSERT INTO user_ai_daily_usage (user_id, source)
  VALUES (p_user_id, 'daily_free');

  RETURN json_build_object('success', TRUE, 'source', 'daily_free');
END;
$$;

-- 3. Fix can_user_sync function
CREATE OR REPLACE FUNCTION can_user_sync(p_user_id UUID, p_platform TEXT)
RETURNS JSON
SET search_path = public, pg_temp
LANGUAGE plpgsql
AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_syncs_today INTEGER;
  v_last_sync_at TIMESTAMPTZ;
  v_cooldown_minutes INTEGER;
  v_daily_limit INTEGER;
  v_wait_seconds INTEGER;
BEGIN
  -- Get premium status
  SELECT COALESCE(is_premium, FALSE) INTO v_is_premium
  FROM user_premium_status
  WHERE user_id = p_user_id;

  -- Get sync stats for today
  SELECT 
    COALESCE(COUNT(*) FILTER (WHERE synced_at::DATE = CURRENT_DATE), 0),
    MAX(synced_at)
  INTO v_syncs_today, v_last_sync_at
  FROM user_sync_history
  WHERE user_id = p_user_id 
    AND platform = p_platform
    AND success = TRUE;

  -- Set limits based on platform and premium status
  IF p_platform = 'psn' THEN
    IF v_is_premium THEN
      v_cooldown_minutes := 30;
      v_daily_limit := 12;
    ELSE
      v_cooldown_minutes := 120;
      v_daily_limit := 3;
    END IF;
  ELSE
    IF v_is_premium THEN
      v_cooldown_minutes := 15;
      v_daily_limit := 999;
    ELSE
      v_cooldown_minutes := 60;
      v_daily_limit := 999;
    END IF;
  END IF;

  -- Check daily limit
  IF v_syncs_today >= v_daily_limit THEN
    RETURN json_build_object(
      'can_sync', FALSE,
      'reason', format('Daily limit reached (%s/%s)', v_syncs_today, v_daily_limit),
      'wait_seconds', 0
    );
  END IF;

  -- Check cooldown
  IF v_last_sync_at IS NOT NULL THEN
    v_wait_seconds := GREATEST(0, 
      EXTRACT(EPOCH FROM (v_last_sync_at + (v_cooldown_minutes || ' minutes')::INTERVAL - NOW()))::INTEGER
    );
    
    IF v_wait_seconds > 0 THEN
      RETURN json_build_object(
        'can_sync', FALSE,
        'reason', format('Cooldown active (%s minutes)', v_cooldown_minutes),
        'wait_seconds', v_wait_seconds
      );
    END IF;
  END IF;

  -- Can sync
  RETURN json_build_object(
    'can_sync', TRUE,
    'syncs_today', v_syncs_today,
    'daily_limit', v_daily_limit
  );
END;
$$;

COMMENT ON FUNCTION can_use_ai IS 'Check if user can use AI features - with secure search_path';
COMMENT ON FUNCTION consume_ai_credit IS 'Consume one AI credit - with secure search_path';
COMMENT ON FUNCTION can_user_sync IS 'Check if user can perform sync - with secure search_path';
