-- AI Credit System for StatusXP
-- Supports: Free daily AI, consumable packs, and premium subscriptions

-- Track user AI credits (purchased packs)
CREATE TABLE IF NOT EXISTS user_ai_credits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  pack_credits INTEGER DEFAULT 0, -- Credits from purchased packs
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Track daily AI usage (free tier)
CREATE TABLE IF NOT EXISTS user_ai_daily_usage (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  usage_date DATE DEFAULT CURRENT_DATE,
  uses_today INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, usage_date)
);

-- Track AI pack purchases
CREATE TABLE IF NOT EXISTS user_ai_pack_purchases (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pack_type VARCHAR(20) NOT NULL, -- 'small', 'medium', 'large'
  credits_purchased INTEGER NOT NULL,
  price_paid DECIMAL(10,2),
  purchase_date TIMESTAMPTZ DEFAULT NOW(),
  platform VARCHAR(20) -- 'google_play', 'app_store', 'paypal'
);

-- Update premium status to include monthly AI credits
ALTER TABLE user_premium_status ADD COLUMN IF NOT EXISTS monthly_ai_credits INTEGER DEFAULT 100;
ALTER TABLE user_premium_status ADD COLUMN IF NOT EXISTS ai_credits_refreshed_at TIMESTAMPTZ DEFAULT NOW();

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_user_ai_credits_user_id ON user_ai_credits(user_id);
CREATE INDEX IF NOT EXISTS idx_user_ai_daily_usage_user_date ON user_ai_daily_usage(user_id, usage_date);
CREATE INDEX IF NOT EXISTS idx_user_ai_pack_purchases_user_id ON user_ai_pack_purchases(user_id);

-- View to show user's total AI availability
CREATE OR REPLACE VIEW user_ai_status AS
SELECT 
  u.id as user_id,
  -- Premium status
  COALESCE(ups.is_premium, false) as is_premium,
  ups.monthly_ai_credits as premium_monthly_limit,
  -- Pack credits
  COALESCE(uac.pack_credits, 0) as pack_credits,
  -- Daily free usage
  COALESCE(udu.uses_today, 0) as uses_today,
  3 as daily_free_limit, -- Free users get 3 per day
  -- Last refresh
  ups.ai_credits_refreshed_at as premium_last_refresh
FROM auth.users u
LEFT JOIN user_premium_status ups ON ups.user_id = u.id
LEFT JOIN user_ai_credits uac ON uac.user_id = u.id
LEFT JOIN user_ai_daily_usage udu ON udu.user_id = u.id AND udu.usage_date = CURRENT_DATE;

-- Function to check if user can use AI
CREATE OR REPLACE FUNCTION can_use_ai(p_user_id UUID) RETURNS JSON AS $$
DECLARE
  v_is_premium BOOLEAN;
  v_pack_credits INTEGER;
  v_uses_today INTEGER;
  v_premium_last_refresh TIMESTAMPTZ;
  v_monthly_ai_credits INTEGER;
  v_can_use BOOLEAN := false;
  v_source TEXT := '';
  v_remaining INTEGER := 0;
BEGIN
  -- Get user AI status
  SELECT 
    is_premium,
    pack_credits,
    uses_today,
    premium_last_refresh,
    premium_monthly_limit
  INTO 
    v_is_premium,
    v_pack_credits,
    v_uses_today,
    v_premium_last_refresh,
    v_monthly_ai_credits
  FROM user_ai_status
  WHERE user_id = p_user_id;

  -- Default to false if no record
  v_is_premium := COALESCE(v_is_premium, false);
  v_pack_credits := COALESCE(v_pack_credits, 0);
  v_uses_today := COALESCE(v_uses_today, 0);
  v_monthly_ai_credits := COALESCE(v_monthly_ai_credits, 100);

  -- Check premium credits first (if premium and needs monthly refresh)
  IF v_is_premium THEN
    -- Check if we need to refresh monthly credits
    IF v_premium_last_refresh IS NULL OR 
       v_premium_last_refresh < DATE_TRUNC('month', NOW()) THEN
      -- Reset monthly credits
      UPDATE user_premium_status
      SET ai_credits_refreshed_at = NOW()
      WHERE user_id = p_user_id;
      
      v_can_use := true;
      v_source := 'premium';
      v_remaining := v_monthly_ai_credits - 1;
      RETURN json_build_object(
        'can_use', v_can_use, 
        'source', v_source, 
        'remaining', v_remaining,
        'pack_credits', v_pack_credits,
        'daily_free', 3 - v_uses_today
      );
    END IF;
    
    -- Premium users get unlimited within their monthly bucket
    -- (We'll track usage but not block for now - simplified)
    v_can_use := true;
    v_source := 'premium';
    v_remaining := v_monthly_ai_credits;
    RETURN json_build_object(
      'can_use', v_can_use, 
      'source', v_source, 
      'remaining', v_remaining,
      'pack_credits', v_pack_credits,
      'daily_free', 3 - v_uses_today
    );
  END IF;

  -- Check pack credits
  IF v_pack_credits > 0 THEN
    v_can_use := true;
    v_source := 'pack';
    v_remaining := v_pack_credits;
    RETURN json_build_object(
      'can_use', v_can_use, 
      'source', v_source, 
      'remaining', v_remaining,
      'pack_credits', v_pack_credits,
      'daily_free', 3 - v_uses_today
    );
  END IF;

  -- Check daily free (3 per day)
  IF v_uses_today < 3 THEN
    v_can_use := true;
    v_source := 'daily_free';
    v_remaining := 3 - v_uses_today;
    RETURN json_build_object(
      'can_use', v_can_use, 
      'source', v_source, 
      'remaining', v_remaining,
      'pack_credits', v_pack_credits,
      'daily_free', v_remaining
    );
  END IF;

  -- No credits available
  RETURN json_build_object(
    'can_use', false, 
    'source', 'none', 
    'remaining', 0,
    'pack_credits', 0,
    'daily_free', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to consume one AI credit
CREATE OR REPLACE FUNCTION consume_ai_credit(p_user_id UUID) RETURNS JSON AS $$
DECLARE
  v_check JSON;
  v_source TEXT;
BEGIN
  -- Check if user can use AI
  v_check := can_use_ai(p_user_id);
  
  IF NOT (v_check->>'can_use')::BOOLEAN THEN
    RETURN v_check;
  END IF;

  v_source := v_check->>'source';

  -- Consume from appropriate source
  IF v_source = 'premium' THEN
    -- Premium users: track usage but don't decrement
    -- (They have a monthly bucket that auto-refreshes)
    NULL; -- No-op for now
  ELSIF v_source = 'pack' THEN
    -- Decrement pack credits
    UPDATE user_ai_credits
    SET pack_credits = pack_credits - 1,
        updated_at = NOW()
    WHERE user_id = p_user_id;
  ELSIF v_source = 'daily_free' THEN
    -- Increment daily usage
    INSERT INTO user_ai_daily_usage (user_id, usage_date, uses_today)
    VALUES (p_user_id, CURRENT_DATE, 1)
    ON CONFLICT (user_id, usage_date) 
    DO UPDATE SET uses_today = user_ai_daily_usage.uses_today + 1;
  END IF;

  -- Return updated status
  RETURN can_use_ai(p_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add pack credits (after purchase)
CREATE OR REPLACE FUNCTION add_ai_pack_credits(
  p_user_id UUID,
  p_pack_type VARCHAR(20),
  p_credits INTEGER,
  p_price DECIMAL(10,2),
  p_platform VARCHAR(20)
) RETURNS JSON AS $$
BEGIN
  -- Add credits to user's account
  INSERT INTO user_ai_credits (user_id, pack_credits)
  VALUES (p_user_id, p_credits)
  ON CONFLICT (user_id)
  DO UPDATE SET 
    pack_credits = user_ai_credits.pack_credits + p_credits,
    updated_at = NOW();

  -- Record purchase
  INSERT INTO user_ai_pack_purchases (user_id, pack_type, credits_purchased, price_paid, platform)
  VALUES (p_user_id, p_pack_type, p_credits, p_price, p_platform);

  -- Return new credit balance
  RETURN json_build_object(
    'success', true,
    'new_balance', (SELECT pack_credits FROM user_ai_credits WHERE user_id = p_user_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comments
COMMENT ON TABLE user_ai_credits IS 'Tracks purchased AI pack credits';
COMMENT ON TABLE user_ai_daily_usage IS 'Tracks daily free AI usage (3 per day)';
COMMENT ON TABLE user_ai_pack_purchases IS 'Records all AI pack purchases';
COMMENT ON FUNCTION can_use_ai IS 'Checks if user has AI credits available (premium > pack > daily free)';
COMMENT ON FUNCTION consume_ai_credit IS 'Uses one AI credit from best available source';
COMMENT ON FUNCTION add_ai_pack_credits IS 'Adds credits after successful pack purchase';
