-- Nuclear option: Delete ALL sessions for this user
-- This will force complete logout

DELETE FROM auth.sessions
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';

-- Verify no sessions remain
SELECT 
    id,
    user_id,
    created_at,
    updated_at
FROM auth.sessions
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';
