-- Repair migration: Add user_premium_status if it doesn't exist
-- This repairs the issue where migration 029 wasn't applied in sequence

-- 1. Create user_premium_status table if missing
CREATE TABLE IF NOT EXISTS user_premium_status (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_premium BOOLEAN DEFAULT FALSE,
  premium_since TIMESTAMPTZ,
  premium_expires_at TIMESTAMPTZ,
  subscription_id TEXT,
  monthly_ai_credits INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'public' 
    AND tablename = 'user_premium_status'
  ) THEN
    ALTER TABLE user_premium_status ENABLE ROW LEVEL SECURITY;
    
    -- RLS Policies
    CREATE POLICY "Users can view their own premium status"
      ON user_premium_status FOR SELECT
      USING (auth.uid() = user_id);

    CREATE POLICY "Users can update their own premium status"
      ON user_premium_status FOR UPDATE
      USING (auth.uid() = user_id);

    CREATE POLICY "Users can insert their own premium status"
      ON user_premium_status FOR INSERT
      WITH CHECK (auth.uid() = user_id);
  END IF;
END $$;

-- Create index if missing
CREATE INDEX IF NOT EXISTS idx_user_premium_status_user_id 
  ON user_premium_status(user_id);

-- Insert default records for existing users who don't have premium status
INSERT INTO user_premium_status (user_id, is_premium, premium_since)
SELECT id, FALSE, NULL
FROM auth.users
WHERE id NOT IN (SELECT user_id FROM user_premium_status)
ON CONFLICT (user_id) DO NOTHING;

-- Grant premium access to your main account
-- TODO: Replace this email with your actual account email, or delete this section if not needed
INSERT INTO user_premium_status (user_id, is_premium, premium_since, monthly_ai_credits)
SELECT id, TRUE, NOW(), 100
FROM auth.users
WHERE email = 'YOUR_EMAIL@EXAMPLE.COM'  -- ⚠️ CHANGE THIS TO YOUR ACTUAL EMAIL
ON CONFLICT (user_id) DO UPDATE SET
  is_premium = TRUE,
  premium_since = COALESCE(user_premium_status.premium_since, NOW()),
  monthly_ai_credits = 100;
