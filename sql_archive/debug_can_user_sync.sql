-- Test the can_user_sync function directly
SELECT * FROM can_user_sync('steam');

-- Also test with no parameter
SELECT * FROM can_user_sync();