-- Check if there's a trigger that's recalculating with old values
-- Show the current trigger definition
SELECT 
  tgname as trigger_name,
  pg_get_triggerdef(oid) as trigger_definition
FROM pg_trigger
WHERE tgrelid = 'user_games'::regclass
AND tgname LIKE '%statusxp%';

-- Also check the function that the trigger calls
SELECT 
  proname as function_name,
  pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname LIKE '%statusxp%'
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
ORDER BY proname;
