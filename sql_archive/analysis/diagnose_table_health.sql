-- Diagnostic queries from external analysis
-- Run these to identify dead/hot tables and IO suspects

-- A) Which tables have had ZERO or minimal writes recently?
SELECT
  schemaname,
  relname as table_name,
  n_tup_ins as inserts,
  n_tup_upd as updates,
  n_tup_del as deletes,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
ORDER BY (n_tup_ins + n_tup_upd + n_tup_del) ASC, relname
LIMIT 50;

-- B) Which tables are huge / hot (IO budget suspects)?
SELECT
  relname as table_name,
  pg_size_pretty(pg_total_relation_size(relid)) as total_size,
  seq_scan,
  idx_scan,
  n_tup_ins,
  n_tup_upd,
  n_tup_del,
  CASE 
    WHEN idx_scan = 0 THEN 0
    ELSE ROUND((seq_scan::numeric / (seq_scan + idx_scan)::numeric) * 100, 2)
  END as seq_scan_percent
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 30;

-- C) Which tables are referenced by foreign keys?
SELECT
  tc.table_name,
  COUNT(*) as fk_count
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
GROUP BY tc.table_name
ORDER BY fk_count ASC, table_name;

-- D) Check for existing unique constraints on critical tables
SELECT
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type,
  STRING_AGG(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) as columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_schema = 'public'
  AND tc.table_name IN ('user_trophies', 'user_achievements', 'user_games')
  AND tc.constraint_type IN ('UNIQUE', 'PRIMARY KEY')
GROUP BY tc.table_name, tc.constraint_name, tc.constraint_type
ORDER BY tc.table_name, tc.constraint_type;
