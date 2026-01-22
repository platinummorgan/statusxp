-- Migration: Add AI Credit System
-- Purpose: Track AI guide usage with daily free credits and purchasable packs

-- 1. Add monthly_ai_credits to user_premium_status (for premium users)
ALTER TABLE user_premium_status
ADD COLUMN IF NOT EXISTS monthly_ai_credits INTEGER DEFAULT 0;

-- 2. Create user_ai_credits table (for purchased pack credits)
CREATE TABLE IF NOT EXISTS user_ai_credits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  pack_credits INTEGER DEFAULT 0, -- Credits from purchased packs
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE user_ai_credits ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own AI credits"
  ON user_ai_credits FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own AI credits"
  ON user_ai_credits FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own AI credits"
  ON user_ai_credits FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 3. Create user_ai_daily_usage table (tracks daily free usage)
CREATE TABLE IF NOT EXISTS user_ai_daily_usage (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  used_at TIMESTAMPTZ DEFAULT NOW(),
  source TEXT CHECK (source IN ('daily_free', 'pack', 'premium'))
);

-- Enable RLS
ALTER TABLE user_ai_daily_usage ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own AI usage"
  ON user_ai_daily_usage FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own AI usage"
  ON user_ai_daily_usage FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_ai_usage_user_date 
  ON user_ai_daily_usage(user_id, used_at DESC);

-- 4. Create user_ai_pack_purchases table (purchase history)
CREATE TABLE IF NOT EXISTS user_ai_pack_purchases (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  pack_type TEXT CHECK (pack_type IN ('small', 'medium', 'large')),
  credits_purchased INTEGER NOT NULL,
  price_usd NUMERIC(10, 2) NOT NULL,
  purchased_at TIMESTAMPTZ DEFAULT NOW(),
  transaction_id TEXT -- Google Play transaction ID
);

-- Enable RLS
ALTER TABLE user_ai_pack_purchases ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own purchase history"
  ON user_ai_pack_purchases FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own purchases"
  ON user_ai_pack_purchases FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 5. Create function to check if user can use AI
CREATE OR REPLACE FUNCTION can_use_ai(p_user_id UUID)
RETURNS JSON AS $$
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
      'remaining', -1, -- Unlimited
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

  -- If user has daily free credits left
  IF v_daily_free_used < v_daily_free_limit THEN
    RETURN json_build_object(
      'can_use', TRUE,
      'source', 'daily_free',
      'remaining', v_daily_free_limit - v_daily_free_used,
      'pack_credits', 0,
      'daily_free_remaining', v_daily_free_limit - v_daily_free_used
    );
  END IF;

  -- No credits available
  RETURN json_build_object(
    'can_use', FALSE,
    'source', NULL,
    'remaining', 0,
    'pack_credits', 0,
    'daily_free_remaining', 0
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION can_use_ai TO authenticated;

-- 6. Create function to consume AI credit
CREATE OR REPLACE FUNCTION consume_ai_credit(p_user_id UUID)
RETURNS JSON AS $$
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

  -- Use daily free if available
  IF v_daily_free_used < v_daily_free_limit THEN
    INSERT INTO user_ai_daily_usage (user_id, source)
    VALUES (p_user_id, 'daily_free');

    RETURN json_build_object('success', TRUE, 'source', 'daily_free');
  END IF;

  -- No credits available
  RETURN json_build_object('success', FALSE, 'error', 'No AI credits available');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION consume_ai_credit TO authenticated;

-- 7. Create function to add pack credits after purchase
CREATE OR REPLACE FUNCTION add_ai_pack_credits(
  p_user_id UUID,
  p_pack_type TEXT,
  p_credits INTEGER,
  p_price_usd NUMERIC,
  p_transaction_id TEXT
)
RETURNS JSON AS $$
BEGIN
  -- Insert purchase record
  INSERT INTO user_ai_pack_purchases (user_id, pack_type, credits_purchased, price_usd, transaction_id)
  VALUES (p_user_id, p_pack_type, p_credits, p_price_usd, p_transaction_id);

  -- Add credits to user account
  INSERT INTO user_ai_credits (user_id, pack_credits)
  VALUES (p_user_id, p_credits)
  ON CONFLICT (user_id)
  DO UPDATE SET 
    pack_credits = user_ai_credits.pack_credits + p_credits,
    updated_at = NOW();

  RETURN json_build_object(
    'success', TRUE,
    'new_balance', (SELECT pack_credits FROM user_ai_credits WHERE user_id = p_user_id)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION add_ai_pack_credits TO authenticated;

-- 8. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_ai_credits_user 
  ON user_ai_credits(user_id);

CREATE INDEX IF NOT EXISTS idx_ai_usage_recent 
  ON user_ai_daily_usage(user_id, used_at DESC)
  WHERE used_at >= CURRENT_DATE - INTERVAL '7 days';

CREATE INDEX IF NOT EXISTS idx_ai_purchases_user 
  ON user_ai_pack_purchases(user_id, purchased_at DESC);
