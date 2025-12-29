-- Fix missing RLS policies for AI credit tables
-- These policies should exist but are showing as missing in Security Advisor

-- 1. Fix user_ai_credits policies
DROP POLICY IF EXISTS "Users can view their own AI credits" ON user_ai_credits;
DROP POLICY IF EXISTS "Users can update their own AI credits" ON user_ai_credits;
DROP POLICY IF EXISTS "Users can insert their own AI credits" ON user_ai_credits;

CREATE POLICY "Users can view their own AI credits"
  ON user_ai_credits FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own AI credits"
  ON user_ai_credits FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own AI credits"
  ON user_ai_credits FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 2. Fix user_ai_daily_usage policies
DROP POLICY IF EXISTS "Users can view their own AI usage" ON user_ai_daily_usage;
DROP POLICY IF EXISTS "Users can insert their own AI usage" ON user_ai_daily_usage;

CREATE POLICY "Users can view their own AI usage"
  ON user_ai_daily_usage FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own AI usage"
  ON user_ai_daily_usage FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- 3. Fix user_ai_pack_purchases policies
DROP POLICY IF EXISTS "Users can view their own purchase history" ON user_ai_pack_purchases;
DROP POLICY IF EXISTS "Users can insert their own purchases" ON user_ai_pack_purchases;

CREATE POLICY "Users can view their own purchase history"
  ON user_ai_pack_purchases FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own purchases"
  ON user_ai_pack_purchases FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Verify RLS is enabled
ALTER TABLE user_ai_credits ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_daily_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_ai_pack_purchases ENABLE ROW LEVEL SECURITY;

-- Add comments
COMMENT ON POLICY "Users can view their own AI credits" ON user_ai_credits IS 'RLS: Users can only view their own AI credit balance';
COMMENT ON POLICY "Users can view their own AI usage" ON user_ai_daily_usage IS 'RLS: Users can only view their own AI usage history';
COMMENT ON POLICY "Users can view their own purchase history" ON user_ai_pack_purchases IS 'RLS: Users can only view their own purchase history';
