-- Check if add_ai_pack_credits function exists
SELECT 
  routine_name,
  routine_type,
  data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%ai%credit%';

-- Also check what parameters it expects
SELECT 
  r.routine_name,
  p.parameter_name,
  p.data_type,
  p.parameter_mode
FROM information_schema.routines r
JOIN information_schema.parameters p 
  ON r.specific_name = p.specific_name
WHERE r.routine_schema = 'public'
  AND r.routine_name = 'add_ai_pack_credits'
ORDER BY p.ordinal_position;
