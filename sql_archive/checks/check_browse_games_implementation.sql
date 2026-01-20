-- ============================================================================
-- Check Browse Games Implementation Status
-- ============================================================================
-- Determine which game browsing function is actually being used
-- ============================================================================

-- 1. Check if game_groups table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_name = 'game_groups'
) as game_groups_exists;

-- 2. Check if get_grouped_games_fast function exists
SELECT EXISTS (
  SELECT FROM pg_proc 
  WHERE proname = 'get_grouped_games_fast'
) as get_grouped_games_fast_exists;

-- 3. Test what the browse games query actually returns
SELECT 
  name,
  platform_id,
  platform_game_id
FROM games
WHERE platform_id = 5  -- Steam
LIMIT 5;

-- 4. Test what happens when we filter Steam in the app
-- The app sends 'steam' as platform_filter to get_grouped_games_fast
-- But get_grouped_games_fast expects platforms like 'psn', 'xbox', 'steam'
-- Let me check the actual games table structure

SELECT 
  g.platform_id,
  g.name,
  COUNT(*) as count
FROM games g
WHERE g.name ILIKE '%baldur%'
GROUP BY g.platform_id, g.name
LIMIT 10;
