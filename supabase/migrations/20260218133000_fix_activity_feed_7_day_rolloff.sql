-- Enforce strict 7-day activity feed window:
-- stories from day 1 should no longer be visible on day 8.

BEGIN;

CREATE OR REPLACE FUNCTION public.cleanup_old_activity_feed()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  deleted_count integer;
BEGIN
  -- Remove stories that have reached their rollover day.
  DELETE FROM public.activity_feed
  WHERE expires_at <= CURRENT_DATE;

  GET DIAGNOSTICS deleted_count = ROW_COUNT;

  RAISE NOTICE 'Activity feed cleanup: deleted % expired stories', deleted_count;
  RETURN deleted_count;
END;
$$;

COMMENT ON FUNCTION public.cleanup_old_activity_feed IS
'Deletes activity feed stories once they reach day 8 (strict 7-day window).';

CREATE OR REPLACE FUNCTION public.get_unread_activity_count(p_user_id uuid)
RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN (
    SELECT COUNT(*)::integer
    FROM public.activity_feed af
    WHERE af.is_visible = true
      AND af.expires_at > CURRENT_DATE
      AND af.created_at > COALESCE(
        (SELECT last_viewed_at FROM public.activity_feed_views WHERE user_id = p_user_id),
        '1970-01-01'::timestamptz
      )
      AND af.user_id <> p_user_id
  );
END;
$$;

COMMENT ON FUNCTION public.get_unread_activity_count IS
'Returns unread count for currently visible activity feed stories (strict 7-day window).';

CREATE OR REPLACE FUNCTION public.get_activity_feed_grouped(
  p_user_id uuid,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  event_date date,
  story_count bigint,
  stories jsonb
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    af.event_date,
    COUNT(*)::bigint AS story_count,
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
    ) AS stories
  FROM public.activity_feed af
  WHERE af.is_visible = true
    AND af.expires_at > CURRENT_DATE
  GROUP BY af.event_date
  ORDER BY af.event_date DESC
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.get_activity_feed_grouped IS
'Returns currently visible activity feed grouped by date (strict 7-day window).';

-- One-time cleanup so existing day-8+ rows roll off immediately.
DELETE FROM public.activity_feed
WHERE expires_at <= CURRENT_DATE;

COMMIT;
