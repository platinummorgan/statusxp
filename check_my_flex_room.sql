-- Check what's in your flex room
SELECT
  user_id,
  tagline,
  flex_of_all_time->>'platform' as flex_platform,
  rarest_flex->>'platform' as rarest_platform,
  most_time_sunk->>'platform' as time_sunk_platform,
  sweattiest_platinum->>'platform' as platinum_platform,
  superlatives
FROM flex_room_data
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Also check what platforms you have games on
SELECT DISTINCT
  p.code as platform,
  COUNT(*) as game_count
FROM user_games ug
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
GROUP BY p.code
ORDER BY game_count DESC;
