-- Backfill current_gamerscore in metadata from max_gamerscore * completion percentage
-- This is an approximation until next sync

UPDATE user_progress
SET metadata = jsonb_set(
  COALESCE(metadata, '{}'::jsonb),
  '{current_gamerscore}',
  to_jsonb(ROUND((metadata->>'max_gamerscore')::numeric * completion_percentage / 100)::integer)
)
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
  AND metadata->>'max_gamerscore' IS NOT NULL;

-- Verify
SELECT 
  platform_id,
  completion_percentage,
  current_score as statusxp,
  metadata->>'current_gamerscore' as gamerscore_display,
  metadata->>'max_gamerscore' as max_gamerscore
FROM user_progress
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform_id IN (10, 11, 12)
LIMIT 10;
