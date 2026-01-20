-- Fix trophy_help_requests.achievement_id column type
-- Change from integer/bigint to TEXT to support platform achievement IDs like "BATHE_IN_FIRE"

-- Drop and recreate the column with correct type
ALTER TABLE trophy_help_requests 
  ALTER COLUMN achievement_id TYPE TEXT USING achievement_id::TEXT;

-- Verify the change
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'trophy_help_requests' 
  AND column_name = 'achievement_id';
