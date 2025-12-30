-- Check if the statusxp_effective trigger/function exists
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'user_games'
ORDER BY trigger_name;
