-- Emergency: Try to recreate basic auth tables (THIS IS DANGEROUS)
-- ONLY run this if you have backups

-- Check what auth tables still exist
SELECT table_name FROM information_schema.tables WHERE table_schema = 'auth' ORDER BY table_name;