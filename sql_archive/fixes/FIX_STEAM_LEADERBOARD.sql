-- STEAM LEADERBOARD FIX
-- Run this script in Supabase SQL Editor to fix Steam leaderboard issues

-- Step 1: Verify steam_leaderboard_cache table exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'steam_leaderboard_cache') THEN
        RAISE NOTICE 'Creating steam_leaderboard_cache table...';
        
        CREATE TABLE steam_leaderboard_cache (
          user_id UUID PRIMARY KEY,
          display_name TEXT,
          avatar_url TEXT,
          achievement_count BIGINT DEFAULT 0,
          total_games BIGINT DEFAULT 0,
          updated_at TIMESTAMPTZ DEFAULT NOW()
        );

        CREATE INDEX idx_steam_leaderboard_cache_achievements 
          ON steam_leaderboard_cache(achievement_count DESC, total_games DESC);
    ELSE
        RAISE NOTICE 'steam_leaderboard_cache table already exists';
    END IF;
END $$;

-- Step 2: Verify refresh function exists
CREATE OR REPLACE FUNCTION refresh_steam_leaderboard_cache()
RETURNS void AS $$
BEGIN
  -- Clear and rebuild
  TRUNCATE steam_leaderboard_cache;
  
  INSERT INTO steam_leaderboard_cache (user_id, display_name, avatar_url, achievement_count, total_games, updated_at)
  SELECT 
    p.id,
    COALESCE(p.steam_display_name, p.display_name),
    p.steam_avatar_url,
    COUNT(DISTINCT ua.id) as achievement_count,
    COUNT(DISTINCT a.game_title_id) as total_games,
    NOW()
  FROM profiles p
  INNER JOIN user_achievements ua ON ua.user_id = p.id
  INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'steam'
  WHERE p.show_on_leaderboard = true
    AND p.steam_id IS NOT NULL
  GROUP BY p.id, p.steam_display_name, p.display_name, p.steam_avatar_url
  HAVING COUNT(DISTINCT ua.id) > 0;
END;
$$ LANGUAGE plpgsql;

-- Step 3: Show current state before refresh
SELECT 'BEFORE REFRESH - Steam users with achievements:' as status;
SELECT 
    p.id,
    p.steam_id,
    p.steam_display_name,
    p.show_on_leaderboard,
    COUNT(DISTINCT ua.id) as achievement_count
FROM profiles p
INNER JOIN user_achievements ua ON ua.user_id = p.id
INNER JOIN achievements a ON a.id = ua.achievement_id AND a.platform = 'steam'
WHERE p.steam_id IS NOT NULL
GROUP BY p.id;

-- Step 4: Manually refresh the cache
SELECT refresh_steam_leaderboard_cache();

-- Step 5: Verify cache was populated
SELECT 'AFTER REFRESH - Cache entries:' as status;
SELECT COUNT(*) as total_entries FROM steam_leaderboard_cache;

-- Step 6: Show who's in the cache
SELECT 'Top 10 Steam leaderboard:' as status;
SELECT * FROM steam_leaderboard_cache ORDER BY achievement_count DESC LIMIT 10;
