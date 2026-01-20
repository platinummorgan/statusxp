-- Add alternate email field to profiles (for reference only, not used for auth)
ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS alternate_email TEXT;

COMMENT ON COLUMN profiles.alternate_email IS 
  'Secondary email for user reference (not used for authentication)';

-- For xdoscbobbles: store gmail as alternate, keep outlook as primary
UPDATE profiles
SET alternate_email = 'oscarmargan20@gmail.com'
WHERE id = 'b23e206a-02d1-4920-b1ee-61ee44583518';

-- Then delete the duplicate account
-- (Run delete_xdoscbobbles_duplicate.sql after this)
