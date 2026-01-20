# Xbox Title ID Backfill Plan

## Problem
- ~350 games have `xbox_title_id = NULL`
- Some are legitimate (PSN/Steam only games)
- Others should have Xbox IDs but were synced before the column existed
- This causes duplicate counting on leaderboards

## Solution Steps

### 1. Backfill Missing xbox_title_id Values

Run the backfill script to populate missing IDs from Xbox API:

```bash
cd sync-service
node backfill-xbox-title-ids.js
```

**What it does:**
- Finds games with NULL `xbox_title_id`
- Skips games that are PSN/Steam only (check metadata)
- Skips games with no Xbox gamerscore in user_games
- Searches Xbox API for each remaining game
- Updates `game_titles.xbox_title_id` with found values

**Expected results:**
- ~66 games updated with valid xbox_title_id
- ~284 games skipped (PSN/Steam games, no Xbox data)

### 2. Handle Remaining Duplicates

After backfill, check for games that still have multiple entries:

```sql
-- Find games with multiple entries where some now have xbox_title_id
SELECT 
  gt.name,
  COUNT(*) as entries,
  STRING_AGG(DISTINCT gt.id::text, ', ') as ids,
  STRING_AGG(DISTINCT gt.xbox_title_id, ', ') as xbox_ids
FROM game_titles gt
WHERE gt.name IN (
  SELECT name 
  FROM game_titles 
  GROUP BY name 
  HAVING COUNT(*) > 1
)
GROUP BY gt.name
HAVING COUNT(*) > 1;
```

**For remaining duplicates:**
- If multiple valid xbox_title_ids exist → Keep all (platform variants)
- If NULL + valid xbox_title_id exist → Merge user_games data, delete NULL entry

### 3. Deploy New Schema (DATABASE_REDESIGN.md Phase 2)

Once data is clean:
- Create new `games` table with composite PK
- Create new `user_progress` table with composite PK
- Prevents future duplicates by design

### 4. Data Migration (DATABASE_REDESIGN.md Phase 3)

Migrate clean data to new structure:
- Deduplicate any remaining issues during migration
- Validate no data loss
- Keep old tables until verified

### 5. App Code Update (DATABASE_REDESIGN.md Phase 4)

Update sync services and app to use new tables

## Why This Order?

1. **Backfill first** - Gives us maximum information for deduplication
2. **Clean duplicates** - Easier to migrate clean data
3. **New schema** - Prevents issues from happening again
4. **Migrate** - Move to optimized structure
5. **Update app** - Use new structure going forward

## Immediate Fix (Temporary)

The COALESCE approach in the leaderboard function already handles this correctly:
```sql
COUNT(DISTINCT COALESCE(gt.xbox_title_id, ug.game_title_id::text)) as total_games
```

This groups by xbox_title_id when available, falling back to game_title_id.
Gordon's totals should be correct once we verify the leaderboard results.
