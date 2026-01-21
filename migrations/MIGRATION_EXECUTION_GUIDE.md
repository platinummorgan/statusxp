# Achievement Comments Migration - Execution Guide

## 📋 Overview

Three migrations to fix `achievement_comments` table to properly reference `achievements` composite primary key.

**Current Problem:**
- `achievement_comments.achievement_id` (bigint) doesn't have a valid FK
- `achievements` uses composite PK: `(platform_id, platform_game_id, platform_achievement_id)`
- 4786/4787 rows can be linked, 1 orphan exists

**Solution:**
- Add composite key columns to `achievement_comments`
- Backfill from existing data
- Choose between deleting orphan + adding FK, or keeping orphan + creating view

---

## 🚀 Execution Steps

### Step 1: Add Columns
**File:** `001_add_achievement_composite_columns_to_comments.sql`

**What it does:**
- Adds 3 columns: `platform_id`, `platform_game_id`, `platform_achievement_id`
- Creates index for backfill performance
- All columns nullable initially

**Run in Supabase SQL Editor:**
```bash
# Copy contents of 001_add_achievement_composite_columns_to_comments.sql
# Paste into SQL Editor
# Execute
```

**Verification:**
```sql
SELECT 
  column_name, 
  data_type, 
  is_nullable
FROM information_schema.columns
WHERE table_name = 'achievement_comments'
  AND column_name IN ('platform_id', 'platform_game_id', 'platform_achievement_id');
```

---

### Step 2: Backfill Data
**File:** `002_backfill_achievement_composite_columns.sql`

**What it does:**
- Converts `achievement_id` (bigint) → `platform_achievement_id` (text)
- JOINs with `achievements` to populate `platform_id` and `platform_game_id`
- Reports success count and orphan warnings

**Run in Supabase SQL Editor:**
```bash
# Copy contents of 002_backfill_achievement_composite_columns.sql
# Paste into SQL Editor
# Execute
```

**Verification:**
```sql
-- Check linked comments
SELECT COUNT(*) as linked_count
FROM achievement_comments
WHERE platform_id IS NOT NULL 
  AND platform_game_id IS NOT NULL;

-- Check orphans
SELECT id, achievement_id, user_id, created_at
FROM achievement_comments
WHERE platform_id IS NULL 
  OR platform_game_id IS NULL;
```

**Expected Results:**
- Linked: 4786 rows
- Orphans: 1 row (id='01399bfa-ba17-40b6-92e6-d3f2c003949f')

---

### Step 3: Enforce Integrity (CHOOSE ONE OPTION)
**File:** `003_enforce_achievement_comments_integrity.sql`

**⚠️ IMPORTANT:** You must uncomment ONE section before running!

#### Option A: Delete Orphan + Add FK (RECOMMENDED)

**Use when:**
- Orphan comment is invalid/spam
- Want full referential integrity immediately
- Ready to commit to composite key approach

**Uncomment Option A section (lines 26-68)**

**What it does:**
- Deletes orphan row `id='01399bfa-ba17-40b6-92e6-d3f2c003949f'`
- Sets columns to `NOT NULL`
- Adds FK constraint with `ON DELETE CASCADE`
- Creates composite index
- Drops old `achievement_id` index
- Marks `achievement_id` column as deprecated

**Verification after running:**
```sql
-- Verify FK exists
SELECT 
  conname, 
  pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conname = 'achievement_comments_achievement_fkey';

-- Verify no orphans
SELECT COUNT(*) FROM achievement_comments;  -- Should be 4786
```

---

#### Option B: Keep Orphan + Create View (SAFER)

**Use when:**
- Need to investigate orphan comment first
- Want to preserve data temporarily
- Testing phase before full enforcement

**Uncomment Option B section (lines 73-126)**

**What it does:**
- Creates view `achievement_comments_attached` (4786 rows, excludes orphan)
- Creates partial index on valid rows only
- Keeps all data intact
- No FK constraint yet

**Verification after running:**
```sql
-- Check view
SELECT COUNT(*) FROM achievement_comments_attached;  -- Should be 4786

-- Check table still has all data
SELECT COUNT(*) FROM achievement_comments;  -- Should be 4787

-- Check orphan still exists
SELECT * FROM achievement_comments 
WHERE id = '01399bfa-ba17-40b6-92e6-d3f2c003949f';
```

**Later (when ready to enforce FK):**
```sql
-- Investigate/fix orphan, then:
DELETE FROM achievement_comments WHERE id = '01399bfa-ba17-40b6-92e6-d3f2c003949f';

ALTER TABLE achievement_comments
  ALTER COLUMN platform_id SET NOT NULL,
  ALTER COLUMN platform_game_id SET NOT NULL,
  ALTER COLUMN platform_achievement_id SET NOT NULL;

ALTER TABLE achievement_comments
  ADD CONSTRAINT achievement_comments_achievement_fkey
  FOREIGN KEY (platform_id, platform_game_id, platform_achievement_id)
  REFERENCES achievements(platform_id, platform_game_id, platform_achievement_id)
  ON DELETE CASCADE;
```

---

## 🔄 Rollback Instructions

### Rollback Migration 003
```sql
-- If you ran OPTION A:
DROP INDEX IF EXISTS idx_achievement_comments_achievement_composite;
ALTER TABLE achievement_comments DROP CONSTRAINT IF EXISTS achievement_comments_achievement_fkey;
ALTER TABLE achievement_comments
  ALTER COLUMN platform_id DROP NOT NULL,
  ALTER COLUMN platform_game_id DROP NOT NULL,
  ALTER COLUMN platform_achievement_id DROP NOT NULL;

-- If you ran OPTION B:
DROP VIEW IF EXISTS achievement_comments_attached;
DROP INDEX IF EXISTS idx_achievement_comments_achievement_composite;
```

### Rollback Migration 002
```sql
UPDATE achievement_comments
SET 
  platform_id = NULL,
  platform_game_id = NULL,
  platform_achievement_id = NULL;
```

### Rollback Migration 001
```sql
DROP INDEX IF EXISTS idx_achievement_comments_achievement_id_backfill;
ALTER TABLE achievement_comments
  DROP COLUMN IF EXISTS platform_id,
  DROP COLUMN IF EXISTS platform_game_id,
  DROP COLUMN IF EXISTS platform_achievement_id;
```

---

## 📊 Impact Assessment

### Database Changes
- **Columns added:** 3 (all initially nullable)
- **Indexes added:** 1-2 (depending on option)
- **FK constraints added:** 0-1 (depending on option)
- **Rows deleted:** 0-1 (depending on option)

### Application Code Impact
- **No immediate code changes required** (old `achievement_id` column still exists)
- **Future update required:** Use composite columns instead of `achievement_id`

### Query Pattern Examples (After Migration)
```sql
-- Old way (still works but deprecated):
SELECT * FROM achievement_comments WHERE achievement_id = 12345;

-- New way (proper):
SELECT * FROM achievement_comments 
WHERE platform_id = 1 
  AND platform_game_id = 'NPWR12345_00' 
  AND platform_achievement_id = '12345';

-- If using Option B view:
SELECT * FROM achievement_comments_attached WHERE ...;
```

---

## ✅ Post-Migration Checklist

- [ ] All 3 migrations executed successfully
- [ ] Verification queries return expected counts
- [ ] FK constraint exists (Option A) OR view exists (Option B)
- [ ] No errors in Supabase logs
- [ ] Test application functionality
- [ ] Update application code to use composite columns
- [ ] (Later) Remove deprecated `achievement_id` column

---

## 🔮 Future Migration: Remove Old Column

After confirming everything works with composite keys:

```sql
-- Future migration: 004_cleanup_old_achievement_id_column.sql
ALTER TABLE achievement_comments 
  DROP COLUMN IF EXISTS achievement_id;

DROP INDEX IF EXISTS idx_achievement_comments_achievement_id;
```

---

## 💡 Recommendation

**Use Option A** unless you have a specific reason to investigate the orphan comment. The single orphan row with `achievement_id=281838` doesn't match any achievement and can be safely removed.
