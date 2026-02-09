-- Manually insert Jasonness's trophy spree story that failed due to constraint

INSERT INTO activity_feed (
  user_id,
  story_text,
  event_type,
  change_type,
  gold_count,
  silver_count,
  bronze_count,
  game_title,
  platform_id,
  username,
  event_date,
  created_at,
  expires_at,
  is_visible,
  ai_model,
  generation_failed
) VALUES (
  '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8',  -- jgmartinez24@gmail.com (Jasonness)
  '🎉 Jasonness is on a trophy spree! 9 Gold, 6 Silver, and 15 Bronze trophies unlocked in PowerWash Simulator!',
  'trophy_with_statusxp',
  'medium',
  9,
  6,
  15,
  'PowerWash Simulator',
  1,  -- PSN platform
  'Jasonness',
  CURRENT_DATE,
  NOW(),
  (CURRENT_DATE + INTERVAL '7 days')::DATE,
  true,
  'gpt-4o-mini',
  false
);

-- Verify it was inserted
SELECT 
  id, 
  story_text, 
  event_type,
  gold_count,
  silver_count,
  bronze_count,
  game_title,
  username,
  event_date
FROM activity_feed
WHERE user_id = '68dd426c-3ce9-45e0-a9e6-70a9d3127eb8'
ORDER BY created_at DESC
LIMIT 1;
