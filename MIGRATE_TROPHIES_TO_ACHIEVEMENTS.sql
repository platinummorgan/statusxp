-- STEP 1: Migrate trophy definitions from trophies → achievements
-- This creates the achievement records that user_achievements can reference

-- First, check how many trophy definitions we'll migrate
SELECT COUNT(DISTINCT t.id) as trophy_definitions_to_migrate
FROM trophies t
WHERE NOT EXISTS (
  SELECT 1 FROM achievements a
  WHERE a.game_title_id = t.game_title_id
    AND a.platform = 'psn'
    AND a.platform_achievement_id = t.psn_trophy_id::text
);

-- Migrate trophy definitions
INSERT INTO achievements (
  game_title_id,
  platform,
  platform_achievement_id,
  name,
  description,
  psn_trophy_type,
  rarity_global,
  is_dlc,
  icon_url,
  created_at
)
SELECT DISTINCT
  t.game_title_id,
  'psn' as platform,
  t.psn_trophy_id::text as platform_achievement_id,
  t.name,
  t.description,
  t.psn_trophy_type,
  t.rarity_global,
  false as is_dlc,  -- trophies table doesn't have is_dlc column
  t.icon_url,
  t.created_at
FROM trophies t
WHERE NOT EXISTS (
  SELECT 1 FROM achievements a
  WHERE a.game_title_id = t.game_title_id
    AND a.platform = 'psn'
    AND a.platform_achievement_id = t.psn_trophy_id::text
)
ON CONFLICT (game_title_id, platform, platform_achievement_id) DO NOTHING;

-- Verify the migration
SELECT COUNT(*) as total_achievements_after_migration
FROM achievements
WHERE platform = 'psn';
