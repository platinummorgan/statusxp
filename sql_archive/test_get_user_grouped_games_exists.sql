-- Test if get_user_grouped_games function exists and works
SELECT * FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid)
LIMIT 3;
