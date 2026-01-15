-- Verify the function exists and has correct permissions
SELECT 
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.prosecdef as security_definer,
    array_agg(pr.rolname) as granted_to
FROM pg_proc p
LEFT JOIN pg_namespace n ON p.pronamespace = n.oid
LEFT JOIN pg_depend d ON d.objid = p.oid AND d.deptype = 'a'
LEFT JOIN pg_auth_members m ON m.member = d.refobjid
LEFT JOIN pg_roles pr ON pr.oid = m.roleid OR pr.oid = d.refobjid
WHERE p.proname = 'unlock_achievement_if_new'
    AND n.nspname = 'public'
GROUP BY p.oid, p.proname, p.prosecdef;

-- Also check if anon/authenticated roles have execute permission
SELECT 
    grantee,
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'unlock_achievement_if_new'
    AND routine_schema = 'public';
