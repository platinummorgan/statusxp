-- Test if check_spike_week function works
-- Replace 'your-user-id-here' with an actual user UUID from profiles table
SELECT public.check_spike_week('00000000-0000-0000-0000-000000000000'::UUID);

-- Get a real user ID to test with
SELECT id FROM profiles LIMIT 1;
