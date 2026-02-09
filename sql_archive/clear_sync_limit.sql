-- Reset PSN daily sync limit for user 84b60ad6-cb2c-484f-8953-bf814551fd7a
DELETE FROM user_sync_history 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform = 'psn'
  AND synced_at::DATE = CURRENT_DATE;

-- Verify reset
SELECT COUNT(*) as remaining_syncs_today
FROM user_sync_history
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND platform = 'psn'
  AND synced_at::DATE = CURRENT_DATE;
