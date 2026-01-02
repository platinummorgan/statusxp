-- Check what achievements exist for RE4 game_title_id 233

SELECT 
  a.id,
  a.name,
  a.platform_achievement_id,
  a.is_platinum,
  a.is_dlc,
  a.dlc_name,
  a.platform_version
FROM achievements a
WHERE a.game_title_id = 233
ORDER BY a.is_platinum DESC, a.is_dlc, a.platform_achievement_id;

-- Count by platform_version (might show PS4 + PS5 mixed together)
SELECT 
  a.platform_version,
  COUNT(*) as count,
  COUNT(*) FILTER (WHERE a.is_platinum) as platinum_count
FROM achievements a
WHERE a.game_title_id = 233
GROUP BY a.platform_version;

-- Delete all achievements for game_title_id 233 so next sync recreates them properly
-- DELETE FROM achievements WHERE game_title_id = 233;
