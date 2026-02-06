-- Activity Feed Feature: Database Tables
-- Created: 2026-02-06
-- 
-- Creates tables for AI-powered activity feed with 7-day rolling window

-- ============================================================
-- 1. USER STAT SNAPSHOTS (Track state over time)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_stat_snapshots (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Core stats
  total_statusxp INT NOT NULL DEFAULT 0,
  platinum_count INT NOT NULL DEFAULT 0,
  
  -- Platform-specific counts
  gamerscore INT DEFAULT 0, -- Xbox only
  psn_gold_count INT DEFAULT 0,
  psn_silver_count INT DEFAULT 0,
  psn_bronze_count INT DEFAULT 0,
  steam_achievement_count INT DEFAULT 0,
  
  -- Context for AI generation
  latest_game_title TEXT,
  latest_platform_id INT,
  
  -- Timing
  synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Indexes
  CONSTRAINT unique_user_sync UNIQUE(user_id, synced_at)
);

CREATE INDEX idx_snapshots_user_time ON user_stat_snapshots(user_id, synced_at DESC);
CREATE INDEX idx_snapshots_cleanup ON user_stat_snapshots(synced_at) WHERE synced_at < NOW() - INTERVAL '30 days';

COMMENT ON TABLE user_stat_snapshots IS 'Captures user stats at each sync for before/after comparison';

-- ============================================================
-- 2. ACTIVITY FEED (AI-Generated Stories)
-- ============================================================
CREATE TABLE IF NOT EXISTS activity_feed (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- AI-generated content
  story_text TEXT NOT NULL,
  
  -- Metadata
  event_type TEXT NOT NULL, -- 'statusxp_gain', 'platinum_milestone', 'gamerscore_gain', 'trophy_detail', 'steam_achievement_gain'
  change_type TEXT, -- 'small', 'medium', 'large', 'massive', 'milestone'
  
  -- Raw change data (for analytics and before/after display)
  old_value INT,
  new_value INT,
  change_amount INT,
  
  -- Trophy breakdowns (PSN only)
  gold_count INT DEFAULT 0,
  silver_count INT DEFAULT 0,
  bronze_count INT DEFAULT 0,
  
  -- Context
  game_title TEXT,
  platform_id INT,
  
  -- Display (denormalized for performance)
  username TEXT NOT NULL,
  avatar_url TEXT,
  
  -- Timing
  event_date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '7 days')::DATE,
  
  -- Privacy
  is_visible BOOLEAN NOT NULL DEFAULT true,
  
  -- Generation metadata
  ai_model TEXT DEFAULT 'gpt-4o-mini',
  generation_failed BOOLEAN NOT NULL DEFAULT false,
  
  -- Constraints
  CHECK (expires_at = (event_date + INTERVAL '7 days')::DATE),
  CHECK (event_type IN ('statusxp_gain', 'platinum_milestone', 'gamerscore_gain', 'trophy_detail', 'steam_achievement_gain'))
);

CREATE INDEX idx_activity_feed_date ON activity_feed(event_date DESC) WHERE is_visible = true;
CREATE INDEX idx_activity_feed_expires ON activity_feed(expires_at);
CREATE INDEX idx_activity_feed_created ON activity_feed(created_at DESC);
CREATE INDEX idx_activity_feed_user ON activity_feed(user_id);
CREATE INDEX idx_activity_feed_type ON activity_feed(event_type);

COMMENT ON TABLE activity_feed IS 'AI-generated stories about user achievements (7-day rolling window)';
COMMENT ON COLUMN activity_feed.expires_at IS 'Auto-delete date (event_date + 7 days)';
COMMENT ON COLUMN activity_feed.story_text IS 'AI-generated announcement with personality';

-- ============================================================
-- 3. ACTIVITY FEED VIEWS (Track Read Status)
-- ============================================================
CREATE TABLE IF NOT EXISTS activity_feed_views (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  last_viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_viewed_id BIGINT, -- Last activity ID they saw
  
  PRIMARY KEY(user_id)
);

CREATE INDEX idx_activity_views_time ON activity_feed_views(last_viewed_at);

COMMENT ON TABLE activity_feed_views IS 'Tracks when users last viewed activity feed for unread counts';

-- ============================================================
-- 4. AUTO-CLEANUP FUNCTION (Delete Expired Stories)
-- ============================================================
CREATE OR REPLACE FUNCTION cleanup_old_activity_feed()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM activity_feed
  WHERE expires_at < CURRENT_DATE;
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RAISE NOTICE 'Activity feed cleanup: deleted % expired stories', deleted_count;
  
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_activity_feed IS 'Deletes activity feed stories older than 7 days (call daily)';

-- ============================================================
-- 5. CLEANUP OLD SNAPSHOTS (Keep Last 30 Days)
-- ============================================================
CREATE OR REPLACE FUNCTION cleanup_old_snapshots()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM user_stat_snapshots
  WHERE synced_at < NOW() - INTERVAL '30 days';
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  RAISE NOTICE 'Snapshot cleanup: deleted % old snapshots', deleted_count;
  
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_snapshots IS 'Deletes snapshots older than 30 days (call daily)';

-- ============================================================
-- 6. GET UNREAD COUNT FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION get_unread_activity_count(p_user_id UUID)
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::INTEGER
    FROM activity_feed af
    WHERE af.is_visible = true
      AND af.created_at > COALESCE(
        (SELECT last_viewed_at FROM activity_feed_views WHERE user_id = p_user_id),
        '1970-01-01'::TIMESTAMPTZ
      )
      AND af.user_id != p_user_id -- Don't count own posts
  );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_unread_activity_count IS 'Returns count of unread activity feed stories for a user';

-- ============================================================
-- 7. GET FEED WITH DATE GROUPING
-- ============================================================
CREATE OR REPLACE FUNCTION get_activity_feed_grouped(
  p_user_id UUID,
  p_limit INT DEFAULT 50
)
RETURNS TABLE (
  event_date DATE,
  story_count BIGINT,
  stories JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    af.event_date,
    COUNT(*)::BIGINT as story_count,
    jsonb_agg(
      jsonb_build_object(
        'id', af.id,
        'user_id', af.user_id,
        'story_text', af.story_text,
        'event_type', af.event_type,
        'username', af.username,
        'avatar_url', af.avatar_url,
        'game_title', af.game_title,
        'created_at', af.created_at,
        'old_value', af.old_value,
        'new_value', af.new_value,
        'change_amount', af.change_amount
      ) ORDER BY af.created_at DESC
    ) as stories
  FROM activity_feed af
  WHERE af.is_visible = true
    AND af.expires_at >= CURRENT_DATE -- Only non-expired
  GROUP BY af.event_date
  ORDER BY af.event_date DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_activity_feed_grouped IS 'Returns activity feed grouped by date with story JSON aggregation';

-- ============================================================
-- 8. MARK FEED AS VIEWED
-- ============================================================
CREATE OR REPLACE FUNCTION mark_activity_feed_viewed(p_user_id UUID)
RETURNS VOID AS $$
BEGIN
  INSERT INTO activity_feed_views (user_id, last_viewed_at)
  VALUES (p_user_id, NOW())
  ON CONFLICT (user_id) 
  DO UPDATE SET last_viewed_at = NOW();
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION mark_activity_feed_viewed IS 'Updates last viewed timestamp to clear unread badge';

-- ============================================================
-- 9. GRANT PERMISSIONS
-- ============================================================
-- Allow authenticated users to read activity feed
GRANT SELECT ON activity_feed TO authenticated;
GRANT SELECT ON user_stat_snapshots TO authenticated;
GRANT SELECT, INSERT, UPDATE ON activity_feed_views TO authenticated;

-- Allow service role to manage everything
GRANT ALL ON activity_feed TO service_role;
GRANT ALL ON user_stat_snapshots TO service_role;
GRANT ALL ON activity_feed_views TO service_role;

-- ============================================================
-- MIGRATION COMPLETE
-- ============================================================
-- Next steps:
-- 1. Run: SELECT cleanup_old_activity_feed(); (test cleanup)
-- 2. Schedule daily: pg_cron or Supabase edge function
-- 3. Integrate with sync services to create snapshots
