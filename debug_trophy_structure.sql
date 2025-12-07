-- Debug: Check if the INSERT is actually finding any rows to insert
SELECT DISTINCT
  t.game_title_id,
  'psn' as platform,
  t.psn_trophy_id::text as platform_achievement_id,
  t.name,
  t.trophy_type
FROM trophies t
WHERE NOT EXISTS (
  SELECT 1 FROM achievements a
  WHERE a.game_title_id = t.game_title_id
    AND a.platform = 'psn'
    AND a.platform_achievement_id = t.psn_trophy_id::text
)
LIMIT 10;

-- Check if there are ANY trophies at all
SELECT COUNT(*) as total_trophies FROM trophies;

-- Check if there are ANY achievements for PSN
SELECT COUNT(*) as total_psn_achievements FROM achievements WHERE platform = 'psn';

-- Sample a few trophies to see their structure
SELECT id, game_title_id, psn_trophy_id, name, trophy_type 
FROM trophies 
LIMIT 5;

-- Sample a few achievements to see their structure
SELECT id, game_title_id, platform_achievement_id, name, psn_trophy_type, platform
FROM achievements 
WHERE platform = 'psn'
LIMIT 5;
