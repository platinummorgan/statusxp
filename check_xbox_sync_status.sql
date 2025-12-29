-- Check if user has Xbox connected and synced

SELECT 
    xbox_gamertag,
    xbox_xuid,
    xbox_sync_status,
    last_xbox_sync_at
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
