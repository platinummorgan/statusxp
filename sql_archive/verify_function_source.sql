-- Get the actual source code of the deployed function
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'unlock_achievement_if_new'
AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');
