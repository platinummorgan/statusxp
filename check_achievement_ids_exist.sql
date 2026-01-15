-- First check what columns exist
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'meta_achievements';

-- Check which achievement IDs from the code actually exist in the database
SELECT *
FROM meta_achievements
WHERE id IN (
  'rare_air', 'baller', 'one_percenter', 'diamond_hands', 'mythic_hunter',
  'elite_finish', 'sweat_lord', 'never_casual', 'fresh_flex', 'warming_up',
  'on_the_grind', 'xp_machine', 'achievement_engine', 'no_life_great_life',
  'double_digits', 'certified_platinum', 'legendary_finisher', 'spike_week',
  'power_session', 'welcome_trophy_room', 'welcome_gamerscore'
)
ORDER BY id;

-- Also check how many total meta achievements exist
SELECT COUNT(*) as total_meta_achievements FROM meta_achievements;
