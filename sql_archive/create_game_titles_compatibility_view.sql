-- ============================================================================
-- CREATE game_titles VIEW - Compatibility layer for V2 schema
-- ============================================================================
-- The app expects to join user_games with game_titles
-- In V2 we only have 'games' table, so create a view for compatibility
--
-- NOTE: In V2 migration (118_migrate_data_to_v2.sql), the proxied URLs from
-- V1 game_titles.proxied_cover_url were copied into games.cover_url
-- So games.cover_url already contains Supabase Storage URLs (not external CDNs)
-- ============================================================================

DROP VIEW IF EXISTS game_titles CASCADE;

CREATE OR REPLACE VIEW game_titles AS
SELECT 
  -- Generate synthetic ID from platform_id and platform_game_id (same as user_games view)
  ('x' || substr(md5(platform_id::text || '_' || platform_game_id), 1, 15))::bit(60)::bigint as id,
  platform_id,
  platform_game_id,
  name,
  cover_url,
  cover_url as proxied_cover_url,  -- Use same URL for compatibility
  icon_url,
  icon_url as proxied_icon_url,    -- Use same URL for compatibility
  metadata,
  created_at,
  updated_at
FROM games;

-- Grant access
GRANT SELECT ON game_titles TO authenticated;
GRANT SELECT ON game_titles TO anon;

-- Verify it works
SELECT 
  id,
  name,
  cover_url,
  platform_id
FROM game_titles
WHERE platform_id IN (10, 11, 12)
LIMIT 10;
