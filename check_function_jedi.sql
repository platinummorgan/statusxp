-- Check what the function returns for Jedi
SELECT 
  group_id,
  name,
  platforms,
  last_played_at
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a')
WHERE LOWER(name) LIKE '%jedi%'
ORDER BY last_played_at DESC;
