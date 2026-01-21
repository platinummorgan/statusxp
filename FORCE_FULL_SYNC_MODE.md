# 🚨 FORCE FULL SYNC MODE - TEMPORARY DATA FIX

**Status:** ACTIVE  
**Duration:** ~1 week (January 21-28, 2026)  
**Purpose:** Fix corrupted `total_achievements` data for all users

## Problem

Some users have incorrect `total_achievements` values in `user_progress` table:
- Xbox games showing `total_achievements = 0` despite earned achievements
- Potentially other platforms with similar issues
- No way to verify which users are affected without them re-syncing

## Solution

Temporarily disable the "skip unchanged games" logic in all sync services for ~1 week. This forces **every sync to reprocess ALL games** and update their data from the platform APIs, fixing any corrupted values.

## Changes Made

### Files Modified

1. **sync-service/steam-sync.js** (lines ~440-450)
   - Disabled: `const needsProcessing = isNewGame || countsChanged || ...`
   - Changed to: `const needsProcessing = true; // FORCE FULL SYNC`
   - Commented out skip logic

2. **sync-service/xbox-sync.js** (lines ~733-745)
   - Disabled: `const needsProcessing = isNewGame || countsChanged || ...`
   - Changed to: `const needsProcessing = true; // FORCE FULL SYNC`
   - Commented out skip logic

3. **sync-service/psn-sync.js**
   - No changes needed - already processes all games every sync

## What Gets Fixed

### All Platforms Update These Fields Correctly:

**user_progress table:**
- ✅ `total_achievements` - Set from API data (Steam: achievements.length, Xbox: totalAchievementsFromAPI, PSN: trophies.length)
- ✅ `achievements_earned` - Set from API data (Steam: unlockedCount, Xbox: currentAchievements, PSN: earnedCount)
- ✅ `completion_percentage` - Recalculated from API
- ✅ `last_achievement_earned_at` - Updated with most recent unlock
- ✅ `metadata.last_rarity_sync` - Timestamp updated
- ✅ `metadata.sync_failed` - Reset to false on success
- ✅ `metadata.sync_error` - Cleared on success

**achievements table:**
- ✅ `rarity_global` - Refreshed from global stats (Steam/Xbox/PSN)
- ✅ `base_status_xp` - Recalculated from rarity
- ✅ `rarity_multiplier` - Recalculated from rarity

**user_achievements table:**
- ✅ All earned achievements re-upserted with latest data

### Data Sources (Truth):

1. **Steam**: `total_achievements` from `achievements.length` (schema API)
2. **Xbox**: `total_achievements` from `totalAchievementsFromAPI` (paginated fetch count)
3. **PSN**: `total_achievements` from `trophies.length` (title trophies API)

## Impact

### Performance
- ⏱️ **Sync times will be MUCH longer** (~5-10x slower)
- All games reprocess achievements instead of skipping unchanged ones
- This is **intentional** - ensures data gets fixed

### User Experience
- Users will see longer sync times (expected)
- Progress bar may move slower than usual
- **All data will be refreshed and corrected**

## Timeline

**Week 1 (Jan 21-28):**
- Force full sync enabled
- All users who sync will get data corrections
- Monitor for complaints about slow syncs

**After Week 1:**
- Re-enable skip logic (revert these changes)
- Normal fast syncs resume
- Data should be clean for all active users

## How to Revert

After ~1 week, uncomment the skip logic in both files:

```javascript
// STEAM & XBOX: Change back to normal
const needsProcessing = isNewGame || countsChanged || needRarityRefresh || missingAchievements || syncFailed;

if (!needsProcessing) {
  console.log(`⏭️  Skip ${game.name} - no changes`);
  processedGames++;
  const progressPercent = Math.floor((processedGames / totalGames) * 100);
  await supabase.from('profiles').update({ [platform]_sync_progress: progressPercent }).eq('id', userId);
  continue;
}
```

## Verification

Check data quality after 1 week:

```sql
-- Should be 0 or very few
SELECT COUNT(*) 
FROM user_progress 
WHERE achievements_earned > 0 AND total_achievements = 0;
```

## Deployment

```bash
cd sync-service
npx @railway/cli up
```

---

**Created:** January 21, 2026  
**Expected Removal:** January 28, 2026  
**Status:** ✅ Deployed to Railway
