-- Check RLS policies and grants for check_spike_week function
SELECT 
  grantee, 
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'check_spike_week'
  AND routine_schema = 'public';

-- Check if function has proper grants for authenticated users
GRANT EXECUTE ON FUNCTION public.check_spike_week(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_spike_week(UUID) TO anon;
