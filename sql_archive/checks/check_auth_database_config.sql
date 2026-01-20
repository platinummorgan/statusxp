-- Check if auth configuration exists in the database
SELECT * FROM auth.config;

-- Check if there are any auth issues
SELECT 
    key,
    value
FROM auth.config 
WHERE key IN ('EXTERNAL_GOOGLE_ENABLED', 'EXTERNAL_GOOGLE_CLIENT_ID', 'EXTERNAL_GOOGLE_SECRET');