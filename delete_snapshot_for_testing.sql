-- Insert a test activity feed story to verify UI works
INSERT INTO activity_feed (
  user_id,
  story_text,
  event_type,
  change_type,
  old_value,
  new_value,
  change_amount,
  gold_count,
  silver_count,
  bronze_count,
  username,
  avatar_url,
  event_date,
  expires_at,
  ai_model,
  generation_failed
) 
SELECT 
  '84b60ad6-cb2c-484f-8953-bf814551fd7a',
  '🎮 ' || COALESCE(psn_online_id, username, 'Gamer') || ' just earned 8 trophies including 2 gold, 3 silver, and 3 bronze! The trophy hunt continues! 🏆',
  'trophy_detail',
  'medium',
  0,
  8,
  8,
  2,
  3,
  3,
  COALESCE(psn_online_id, username, 'Gamer'),
  avatar_url,
  CURRENT_DATE,
  (CURRENT_DATE + INTERVAL '7 days')::DATE,
  'test',
  false
FROM profiles 
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Verify it was created
SELECT story_text, event_type, created_at
FROM activity_feed
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY created_at DESC
LIMIT 1;
