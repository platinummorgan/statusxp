-- Database Size Analysis
-- Run this to check disk space usage

-- Overall database size
SELECT 
    pg_size_pretty(pg_database_size(current_database())) as total_database_size,
    pg_database_size(current_database()) as total_bytes;

-- Table sizes (top 20 largest tables)
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size,
    pg_total_relation_size(schemaname||'.'||tablename) as bytes
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- Materialized views size
SELECT 
    schemaname,
    matviewname,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) AS total_size
FROM pg_matviews
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||matviewname) DESC;

-- Index sizes (top 20 largest)
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(schemaname||'.'||indexname)) AS index_size,
    pg_relation_size(schemaname||'.'||indexname) as bytes
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(schemaname||'.'||indexname) DESC
LIMIT 20;

-- Row counts for main tables
SELECT 
    schemaname,
    relname as tablename,
    n_live_tup as estimated_rows
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC
LIMIT 20;

-- Summary: Top space consumers
SELECT 
    'Tables' as category,
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||tablename))) as total_size
FROM pg_tables
WHERE schemaname = 'public'
UNION ALL
SELECT 
    'Indexes' as category,
    pg_size_pretty(sum(pg_relation_size(schemaname||'.'||indexname))) as total_size
FROM pg_indexes
WHERE schemaname = 'public'
UNION ALL
SELECT 
    'Materialized Views' as category,
    pg_size_pretty(sum(pg_total_relation_size(schemaname||'.'||matviewname))) as total_size
FROM pg_matviews
WHERE schemaname = 'public';
