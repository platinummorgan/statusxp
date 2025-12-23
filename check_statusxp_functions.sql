-- Check if StatusXP calculation functions exist
SELECT 
  p.proname as function_name,
  pg_get_function_arguments(p.oid) as arguments,
  pg_get_functiondef(p.oid) as definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname IN ('calculate_user_achievement_statusxp', 'calculate_user_game_statusxp')
ORDER BY p.proname;
