-- Check if 'cancelling' is a valid status in the database constraint

-- Check PSN sync status constraint
SELECT 
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conname LIKE '%psn_sync_status%'
  AND conrelid = 'profiles'::regclass;

-- Check if your profile has cancelling status
SELECT 
  id,
  username,
  psn_sync_status,
  last_psn_sync_at
FROM profiles
WHERE psn_sync_status = 'cancelling';

-- Check all possible PSN sync statuses in use
SELECT DISTINCT psn_sync_status, COUNT(*)
FROM profiles
GROUP BY psn_sync_status
ORDER BY COUNT(*) DESC;
