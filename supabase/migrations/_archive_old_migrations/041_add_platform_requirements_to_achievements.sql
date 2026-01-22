-- Add platform requirements to meta achievements
-- This allows filtering achievements based on what platforms users have connected

-- Add required_platforms column
ALTER TABLE meta_achievements ADD COLUMN IF NOT EXISTS required_platforms TEXT[];

-- Add comment explaining the column
COMMENT ON COLUMN meta_achievements.required_platforms IS 
  'Array of platform codes required to earn this achievement. NULL = available to all. Examples: [''psn''], [''xbox''], [''steam''], [''psn'',''xbox'',''steam''] for cross-platform';

-- Mark existing platform-specific achievements
UPDATE meta_achievements SET required_platforms = ARRAY['psn']
WHERE id = 'welcome_trophy_room';

UPDATE meta_achievements SET required_platforms = ARRAY['xbox']
WHERE id = 'welcome_gamerscore';

UPDATE meta_achievements SET required_platforms = ARRAY['steam']
WHERE id = 'welcome_pc_grind';

-- Mark cross-platform achievements (require all 3)
UPDATE meta_achievements SET required_platforms = ARRAY['psn', 'xbox', 'steam']
WHERE id IN ('triforce', 'cross_platform_conqueror', 'systems_online');

-- So Close It Hurts only works on Xbox/Steam (not PS due to platinum auto-complete)
UPDATE meta_achievements SET required_platforms = ARRAY['xbox', 'steam']
WHERE id = 'so_close_it_hurts';
