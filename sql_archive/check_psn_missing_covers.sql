-- Check what PSN games have null cover_url in their metadata

-- Check if trophyTitleIconUrl was provided by PSN API
SELECT 
  name,
  platform_game_id,
  cover_url,
  metadata->>'psn_np_communication_id' as npwr_id,
  metadata->>'last_api_seen_at' as last_synced
FROM games
WHERE platform_id = 1  -- PS5
  AND cover_url IS NULL
ORDER BY name
LIMIT 20;

-- Count how many were synced vs never synced
SELECT 
  CASE 
    WHEN metadata->>'last_api_seen_at' IS NOT NULL THEN 'Synced (API provided no cover)'
    ELSE 'Never synced'
  END as status,
  COUNT(*) as count
FROM games
WHERE platform_id = 1 AND cover_url IS NULL
GROUP BY status;
