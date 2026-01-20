-- Remove problematic unique constraint on game name
-- This was preventing games with the same name (originals vs remakes) from existing

-- Drop the constraint that prevents duplicate names
DROP INDEX IF EXISTS idx_game_titles_name_unique;

-- Add a better unique constraint on npCommunicationId (the actual unique identifier)
CREATE UNIQUE INDEX IF NOT EXISTS idx_game_titles_psn_np_comm_id_unique 
ON game_titles ((metadata->>'psn_np_communication_id')) 
WHERE metadata->>'psn_np_communication_id' IS NOT NULL;

-- Verify no constraint on name anymore
SELECT 
  conname, 
  contype,
  pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conrelid = 'game_titles'::regclass
  AND conname LIKE '%name%';
