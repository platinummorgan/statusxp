-- Test the function directly to see actual order
SELECT 
  name,
  last_played_at,
  (platforms[1]->>'code') as platform
FROM get_user_grouped_games('84b60ad6-cb2c-484f-8953-bf814551fd7a')
LIMIT 10;
