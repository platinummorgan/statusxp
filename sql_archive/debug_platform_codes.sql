-- Debug query to see actual platform codes returned for a user
-- Run with actual user_id

SELECT 
  jsonb_pretty(jsonb_build_object(
    'code', LOWER(
      CASE 
        WHEN p.code IN ('PS3', 'PS4', 'PS5', 'PSVITA') THEN 'psn'
        WHEN p.code IN ('XBOX360', 'XBOXONE', 'XBOXSERIESX', 'Xbox') THEN 'xbox'
        WHEN p.code = 'Steam' THEN 'steam'
        ELSE 'unknown'
      END
    ),
    'platform_id', ug.platform_id,
    'platform_code_raw', p.code,
    'game_title', ug.game_title
  )) as platform_info
FROM user_games ug
LEFT JOIN platforms p ON p.id = ug.platform_id
WHERE ug.user_id = 'USER_ID_HERE'::uuid
LIMIT 20;
