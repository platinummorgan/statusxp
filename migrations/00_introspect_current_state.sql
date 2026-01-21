-- ============================================================================
-- DATABASE INTROSPECTION - DISCOVER ACTUAL CONSTRAINT STATE
-- ============================================================================
-- Run these queries in Supabase SQL Editor to discover the TRUE state
-- of the database before attempting any fixes.
--
-- IMPORTANT: Copy the FULL output of each query and paste back to continue.
-- ============================================================================

-- ============================================================================
-- QUERY A: ALL CONSTRAINTS ON TARGET TABLES
-- ============================================================================
-- This will show us PRIMARY KEYS, FOREIGN KEYS, UNIQUE constraints, CHECK constraints
-- With the ACTUAL constraint names that exist in the database

SELECT
  con.oid,
  n.nspname AS schema,
  c.relname AS table_name,
  con.conname AS constraint_name,
  pg_get_constraintdef(con.oid) AS constraint_def,
  CASE con.contype
    WHEN 'c' THEN 'CHECK'
    WHEN 'f' THEN 'FOREIGN KEY'
    WHEN 'p' THEN 'PRIMARY KEY'
    WHEN 'u' THEN 'UNIQUE'
    WHEN 't' THEN 'TRIGGER'
    WHEN 'x' THEN 'EXCLUSION'
    ELSE con.contype::text
  END AS constraint_type
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'achievements',
    'games',
    'user_achievements',
    'user_progress',
    'flex_room_data',
    'achievement_comments',
    'trophy_help_requests',
    'trophy_help_responses'
  )
ORDER BY c.relname, con.contype, con.conname;

-- ============================================================================
-- QUERY B: ALL INDEXES ON TARGET TABLES
-- ============================================================================
-- This shows both automatic indexes (from PKs/UNIQUEs) and manual indexes

SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'achievements',
    'games',
    'user_achievements',
    'user_progress',
    'flex_room_data',
    'achievement_comments',
    'trophy_help_requests',
    'trophy_help_responses'
  )
ORDER BY tablename, indexname;

-- ============================================================================
-- QUERY C: PRIMARY KEY AND UNIQUE CONSTRAINT COLUMNS (DETAILED)
-- ============================================================================
-- Shows which columns make up each PK/UNIQUE constraint and their order

SELECT
  tc.table_name,
  tc.constraint_name,
  tc.constraint_type,
  kcu.column_name,
  kcu.ordinal_position
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema = 'public'
  AND tc.table_name IN (
    'achievements',
    'games',
    'user_achievements',
    'user_progress',
    'flex_room_data',
    'achievement_comments'
  )
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name, kcu.ordinal_position;

-- ============================================================================
-- QUERY D: TABLE COLUMNS WITH DATA TYPES
-- ============================================================================
-- Verify the actual column structure

SELECT
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default,
  ordinal_position
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'achievements',
    'games',
    'user_achievements',
    'user_progress',
    'flex_room_data',
    'achievement_comments'
  )
ORDER BY table_name, ordinal_position;

-- ============================================================================
-- QUERY E: FOREIGN KEY RELATIONSHIPS (DETAILED)
-- ============================================================================
-- Shows source table, source columns, target table, target columns

SELECT
  tc.table_name AS from_table,
  kcu.column_name AS from_column,
  ccu.table_name AS to_table,
  ccu.column_name AS to_column,
  tc.constraint_name,
  rc.update_rule,
  rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
JOIN information_schema.referential_constraints AS rc
  ON tc.constraint_name = rc.constraint_name
  AND tc.table_schema = rc.constraint_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name IN (
    'achievements',
    'games',
    'user_achievements',
    'user_progress',
    'flex_room_data',
    'achievement_comments'
  )
ORDER BY tc.table_name, tc.constraint_name, kcu.ordinal_position;

-- ============================================================================
-- INSTRUCTIONS
-- ============================================================================
--
-- 1. Open Supabase Dashboard → SQL Editor
-- 2. Run each query section (A through E) one at a time
-- 3. Copy the COMPLETE results (all rows) for each query
-- 4. Paste the results back into the chat
-- 5. I will analyze the actual constraint names and generate precise migrations
--
-- DO NOT proceed with any migrations until we have these results!
-- The schema documentation may not match the actual database state.
-- ============================================================================
