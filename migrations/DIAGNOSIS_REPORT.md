# Database Schema Constraint Issues - Diagnosis Report

**Date:** 2026-01-21  
**Database:** Supabase PostgreSQL  
**Severity:** CRITICAL - Multiple invalid foreign key constraints preventing proper referential integrity

---

## Executive Summary

The database schema contains **62 invalid foreign key constraints** across 5 tables that violate PostgreSQL foreign key rules. These constraints attempt to reference composite primary keys one column at a time, creating duplicate constraint names and invalid references.

**Impact:**
- Data integrity is NOT enforced at the database level
- Orphaned records are possible
- Application-level joins may succeed but database constraints won't prevent bad data
- Schema cannot be cleanly exported or imported

---

## Detailed Findings

### 1. **achievements** table - 4 Invalid Foreign Keys

**Location:** Lines 36-39 of schema  
**Severity:** CRITICAL

```sql
-- BROKEN: All constraints have the SAME NAME (duplicate) and reference ONE column at a time
CONSTRAINT achievements_platform_id_platform_game_id_fkey FOREIGN KEY (platform_id) REFERENCES public.games(platform_id),
CONSTRAINT achievements_platform_id_platform_game_id_fkey FOREIGN KEY (platform_game_id) REFERENCES public.games(platform_id),
CONSTRAINT achievements_platform_id_platform_game_id_fkey FOREIGN KEY (platform_id) REFERENCES public.games(platform_game_id),
CONSTRAINT achievements_platform_id_platform_game_id_fkey FOREIGN KEY (platform_game_id) REFERENCES public.games(platform_game_id)
```

**Problems:**
1. Duplicate constraint name used 4 times (PostgreSQL allows only unique names)
2. References `games(platform_id)` alone - NOT VALID (games PK is composite: platform_id + platform_game_id)
3. References `games(platform_game_id)` alone - NOT VALID (not unique without platform_id)
4. Logical error: Each FK tries to reference a single column from a composite key

**Expected behavior:**
```sql
-- CORRECT: Single FK referencing the full composite key
CONSTRAINT achievements_games_fkey 
  FOREIGN KEY (platform_id, platform_game_id) 
  REFERENCES public.games(platform_id, platform_game_id)
```

---

### 2. **user_achievements** table - 9 Invalid Foreign Keys

**Location:** Lines 319-327 of schema  
**Severity:** CRITICAL

```sql
-- BROKEN: All 9 constraints have the SAME NAME and reference individual columns
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_id) REFERENCES public.achievements(platform_id),
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_game_id) REFERENCES public.achievements(platform_id),
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_achievement_id) REFERENCES public.achievements(platform_id),
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_id) REFERENCES public.achievements(platform_game_id),
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_game_id) REFERENCES public.achievements(platform_game_id),
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_achievement_id) REFERENCES public.achievements(platform_game_id),
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_id) REFERENCES public.achievements(platform_achievement_id),
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_game_id) REFERENCES public.achievements(platform_achievement_id),
CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_achievement_id) REFERENCES public.achievements(platform_achievement_id)
```

**Problems:**
1. Duplicate constraint name used 9 times
2. Attempts to reference composite PK (platform_id, platform_game_id, platform_achievement_id) one column at a time
3. None of the individual columns are unique in achievements table
4. Results in NO actual foreign key enforcement

**Expected behavior:**
```sql
-- CORRECT: Single FK referencing the full composite key
CONSTRAINT user_achievements_achievements_fkey 
  FOREIGN KEY (platform_id, platform_game_id, platform_achievement_id) 
  REFERENCES public.achievements(platform_id, platform_game_id, platform_achievement_id)
```

---

### 3. **user_progress** table - 4 Invalid Foreign Keys

**Location:** Lines 414-417 of schema  
**Severity:** CRITICAL

```sql
-- BROKEN: All constraints have the SAME NAME and reference individual columns
CONSTRAINT user_progress_platform_id_platform_game_id_fkey FOREIGN KEY (platform_id) REFERENCES public.games(platform_id),
CONSTRAINT user_progress_platform_id_platform_game_id_fkey FOREIGN KEY (platform_game_id) REFERENCES public.games(platform_id),
CONSTRAINT user_progress_platform_id_platform_game_id_fkey FOREIGN KEY (platform_id) REFERENCES public.games(platform_game_id),
CONSTRAINT user_progress_platform_id_platform_game_id_fkey FOREIGN KEY (platform_game_id) REFERENCES public.games(platform_game_id)
```

**Problems:**
1. Same duplicate name issue (4 times)
2. Tries to reference games composite PK one column at a time
3. No referential integrity enforced

**Expected behavior:**
```sql
-- CORRECT: Single FK referencing the full composite key
CONSTRAINT user_progress_games_fkey 
  FOREIGN KEY (platform_id, platform_game_id) 
  REFERENCES public.games(platform_id, platform_game_id)
```

---

### 4. **flex_room_data** table - 36 Invalid Foreign Keys

**Location:** Lines 71-109 of schema  
**Severity:** CRITICAL - Most complex case

The table has 4 achievement reference fields, each with 9 duplicate/invalid FKs:

1. **flex_of_all_time** fields (9 broken FKs)
2. **rarest_flex** fields (9 broken FKs)
3. **most_time_sunk** fields (9 broken FKs)
4. **sweatiest_platinum** fields (9 broken FKs)

**Pattern (repeated 4 times):**
```sql
-- Example for flex_of_all_time (same pattern for other 3 fields)
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_id) REFERENCES public.achievements(platform_id),
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_game_id) REFERENCES public.achievements(platform_id),
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_achievement_id) REFERENCES public.achievements(platform_id),
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_id) REFERENCES public.achievements(platform_game_id),
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_game_id) REFERENCES public.achievements(platform_game_id),
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_achievement_id) REFERENCES public.achievements(platform_game_id),
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_id) REFERENCES public.achievements(platform_achievement_id),
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_game_id) REFERENCES public.achievements(platform_achievement_id),
CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_achievement_id) REFERENCES public.achievements(platform_achievement_id)
```

**Problems:**
1. Each constraint name is duplicated 9 times
2. 36 total invalid FKs attempting to reference composite keys incorrectly
3. Completely breaks referential integrity for flex room data

**Expected behavior:**
```sql
-- CORRECT: One FK per achievement reference (4 total)
CONSTRAINT fk_flex_of_all_time 
  FOREIGN KEY (flex_of_all_time_platform_id, flex_of_all_time_platform_game_id, flex_of_all_time_platform_achievement_id) 
  REFERENCES public.achievements(platform_id, platform_game_id, platform_achievement_id),
  
CONSTRAINT fk_rarest_flex 
  FOREIGN KEY (rarest_flex_platform_id, rarest_flex_platform_game_id, rarest_flex_platform_achievement_id) 
  REFERENCES public.achievements(platform_id, platform_game_id, platform_achievement_id),
  
-- ... etc for other 2 fields
```

---

### 5. **achievement_comments** table - Type Mismatch

**Location:** Line 6 of schema  
**Severity:** HIGH

```sql
achievement_id bigint NOT NULL,
-- But no FK constraint shown; likely missing or broken
```

**Problems:**
1. Column `achievement_id` is defined as `bigint`
2. But `achievements` table has NO `id` column
3. The achievements PK is composite: (platform_id, platform_game_id, platform_achievement_id)
4. No valid FK can be created from bigint → composite key

**Expected behavior (2 options):**
- **Option A (Composite):** Add 3 columns: `platform_id`, `platform_game_id`, `platform_achievement_id` + composite FK
- **Option B (Surrogate - PREFERRED):** Add surrogate `id` to achievements, keep `achievement_id bigint` in comments

---

## Summary Table

| Table | Invalid FKs | Constraint Names | Issue Type |
|-------|-------------|------------------|------------|
| achievements | 4 | achievements_platform_id_platform_game_id_fkey (x4) | Duplicate name, partial composite FK |
| user_achievements | 9 | user_achievements_v2_platform_id_platform_game_id_platform_fkey (x9) | Duplicate name, partial composite FK |
| user_progress | 4 | user_progress_platform_id_platform_game_id_fkey (x4) | Duplicate name, partial composite FK |
| flex_room_data | 36 | fk_flex_of_all_time (x9), fk_rarest_flex (x9), fk_most_time_sunk (x9), fk_sweatiest_platinum (x9) | Duplicate names, partial composite FKs |
| achievement_comments | 1 (missing) | N/A | Type mismatch - bigint referencing composite key |
| **TOTAL** | **54** | **8 unique names (all duplicated)** | **Composite key reference errors** |

---

## Additional Issues

### User Reference Inconsistency

Some tables reference `auth.users(id)` while others reference `public.profiles(id)`:

**Using auth.users:**
- psn_sync_logs
- steam_sync_logs
- trophy_help_requests
- trophy_help_responses
- user_selected_title
- user_ai_credits
- user_ai_daily_usage
- user_ai_pack_purchases
- user_meta_achievements
- user_premium_status
- user_sync_history
- xbox_sync_logs

**Using public.profiles:**
- user_achievements (correct)
- user_progress (correct)
- user_stats (correct)
- psn_user_trophy_profile (correct)
- leaderboard_cache (correct)

**Recommendation:** 
- Keep `profiles.id` as FK reference point (it already references auth.users)
- Standardize all user_id FKs to reference `public.profiles(id)` for consistency
- profiles acts as the domain model; auth.users is auth-only

---

## Missing Indexes

High-traffic joins lack indexes:

1. `user_achievements(user_id)` - needs index
2. `user_achievements(platform_id, platform_game_id, platform_achievement_id)` - covered by PK
3. `user_progress(user_id)` - covered by PK
4. `trophy_help_requests(status, created_at DESC)` - needs composite index
5. `achievement_comments(achievement_id, created_at DESC)` - needs composite index (after FK fix)

---

## Root Cause Analysis

These errors likely originated from:
1. **Misunderstanding of composite FK syntax** - Someone tried to create 1 FK per column instead of 1 multi-column FK
2. **Migration generation bug** - ORM or migration tool may have generated incorrect syntax
3. **Lack of validation** - Schema was never actually applied (would fail) OR constraints were added via ALTER TABLE with syntax errors that were ignored

---

## Impact Assessment

**Current State:**
- ❌ NO referential integrity enforcement
- ❌ Orphaned records possible
- ❌ Schema cannot be exported/imported cleanly
- ❌ Database tools (pgAdmin, etc.) will show errors
- ⚠️ Application code must handle integrity (unreliable)

**After Fix:**
- ✅ Database-level referential integrity
- ✅ Cascading deletes/updates possible
- ✅ Query optimizer can use FK relationships
- ✅ Clean schema exports
- ✅ Reduced application complexity

---

## Next Steps

See `MIGRATION_PLAN.md` for detailed fix strategy using surrogate keys.
