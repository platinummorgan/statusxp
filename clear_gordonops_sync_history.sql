-- Delete gordonops' sync history to bypass rate limit
DELETE FROM user_sync_history
WHERE user_id = (SELECT id FROM profiles WHERE username = 'gordonops')
  AND platform = 'psn';

-- Verify deletion
SELECT COUNT(*) as remaining_psn_syncs
FROM user_sync_history
WHERE user_id = (SELECT id FROM profiles WHERE username = 'gordonops')
  AND platform = 'psn';
