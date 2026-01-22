-- Allow the same trophy to be displayed in multiple positions
-- Drop the unique constraint that prevents duplicate trophies per user
ALTER TABLE display_case_items 
DROP CONSTRAINT IF EXISTS display_case_items_user_id_trophy_id_key;

-- Keep the position constraint (user can only have one trophy per position)
-- This should already exist, but ensure it's there
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'display_case_items_user_id_shelf_position_key'
  ) THEN
    ALTER TABLE display_case_items 
    ADD CONSTRAINT display_case_items_user_id_shelf_position_key 
    UNIQUE (user_id, shelf_number, position_in_shelf);
  END IF;
END $$;
