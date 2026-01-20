-- Check user_meta_achievements table constraints
SELECT 
    conname AS constraint_name,
    contype AS constraint_type,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'user_meta_achievements'::regclass;

-- Check recent failed inserts (if there are any logged)
SELECT * FROM user_meta_achievements 
ORDER BY created_at DESC 
LIMIT 5;
