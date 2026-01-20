-- Check if auth schema got corrupted by our database changes
SELECT table_name FROM information_schema.tables WHERE table_schema = 'auth';

-- Check if Google provider still exists
SELECT * FROM auth.providers WHERE provider = 'google';

-- Check auth configuration
SELECT 
    key,
    value 
FROM auth.config 
WHERE key LIKE '%google%' OR key LIKE '%oauth%';