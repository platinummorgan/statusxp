-- Check if auth.config and auth.providers tables exist
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'auth' AND table_name = 'config'
    ) THEN 'auth.config EXISTS' 
    ELSE 'auth.config MISSING' 
    END as config_status;

SELECT 
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'auth' AND table_name = 'providers'
    ) THEN 'auth.providers EXISTS' 
    ELSE 'auth.providers MISSING' 
    END as providers_status;