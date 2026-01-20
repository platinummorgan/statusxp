-- Check auth configuration after restore
SELECT * FROM auth.config;

-- Check OAuth providers
SELECT * FROM auth.providers WHERE provider = 'google';

-- Check if Google is enabled in auth config
SELECT 
    CASE 
        WHEN external_google_enabled THEN 'Google OAuth ENABLED' 
        ELSE 'Google OAuth DISABLED' 
    END as google_status
FROM auth.config;