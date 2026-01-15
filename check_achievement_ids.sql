-- Check which achievement IDs are stored
SELECT 
  achievement_id,
  unlocked_at
FROM user_meta_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY achievement_id;
