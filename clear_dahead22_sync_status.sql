-- Clear PSN sync status for DaHead22 to allow fresh sync after fixes

-- User: djheygood (username), DaHead22 (PSN ID)
-- UUID: 3c5206fb-6806-4f95-80d6-29ee7e974be9

UPDATE profiles
SET 
    psn_sync_status = NULL,
    psn_sync_progress = 0,
    last_psn_sync_at = NULL
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Verify sync status cleared
SELECT 
    username,
    psn_sync_status,
    psn_sync_progress,
    last_psn_sync_at
FROM profiles
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';
