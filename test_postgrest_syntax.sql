-- Test the PostgREST join syntax that Supabase uses
-- This simulates: .select('achievement_id, earned_at, achievements!inner(game_title_id)')

SELECT 
  ua.achievement_id,
  ua.earned_at,
  json_build_object('game_title_id', a.game_title_id) as achievements
FROM user_achievements ua
INNER JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.earned_at IS NOT NULL
ORDER BY ua.earned_at DESC
LIMIT 5;
