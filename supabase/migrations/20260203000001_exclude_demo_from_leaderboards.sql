-- Exclude demo account from leaderboards
-- The demo account (demo@statusxp.test) should not appear in competitive leaderboards

-- Add is_demo flag to profiles table
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS is_demo BOOLEAN DEFAULT FALSE;

-- Mark the demo account
UPDATE profiles
SET is_demo = TRUE
WHERE id IN (
  SELECT id FROM auth.users WHERE email = 'demo@statusxp.test'
);

-- Create index for efficient filtering
CREATE INDEX IF NOT EXISTS idx_profiles_is_demo ON profiles(is_demo) WHERE is_demo = FALSE;

-- Note: Update your leaderboard cache refresh queries to add:
-- WHERE p.is_demo = FALSE OR p.is_demo IS NULL
-- This will exclude demo accounts from all leaderboard calculations
