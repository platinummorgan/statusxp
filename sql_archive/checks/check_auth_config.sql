-- Check current auth providers and configuration
SELECT 
    provider,
    enabled,
    config
FROM auth.providers;