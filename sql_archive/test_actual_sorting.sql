-- Test with your actual user_id
SELECT 
  name,
  platforms[1]->>'code' as platform,
  last_played_at
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a')
ORDER BY last_played_at DESC NULLS LAST
LIMIT 20;
