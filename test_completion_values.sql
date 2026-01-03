-- Test the actual completion values being returned
SELECT * FROM get_user_grouped_games('YOUR_USER_ID_HERE')
WHERE name ILIKE '%Disney%'
LIMIT 1;
