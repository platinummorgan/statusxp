# CRITICAL BUG: Cross-Platform Version Trophy Contamination

**Severity:** CRITICAL  
**Impact:** All users with cross-gen/remaster games  
**Discovered:** December 29, 2025

## Problem Summary

Games with multiple platform versions (PS4/PS5, remasters, etc.) are being stored as a SINGLE `game_titles` entry, causing trophy lists from different versions to merge. This allows users to receive trophies/achievements they never earned.

## Real-World Example

**What Remains of Edith Finch:**
- PS4 version: 9 trophies, NO platinum
- PS5 version: 10 trophies, HAS platinum "All Done"
- Database: ONE game_titles entry (ID 264) with 12 trophies mixed together
- Result: User with PS4 version got credited with PS5 platinum

## Affected Games (Examples)

This affects HUNDREDS of games:
- Resident Evil series (RE1-7, multiple versions each)
- Uncharted series (PS3 + PS4 Nathan Drake Collection)
- Batman Arkham series (Original + Return to Arkham)
- Final Fantasy series (Original + Remasters + Pixel Remasters)
- God of War series (PS3 + Collections + Remasters)
- Assassin's Creed series (Multiple platform versions)
- Every PS4 game with a PS5 upgrade
- Every Xbox 360 game with Xbox One/Series X version
- Every remaster/definitive edition

## Root Cause

### Current (Broken) Logic:
```javascript
// Sync matches games by NAME only
const existingGame = await supabase
  .from('game_titles')
  .select('*')
  .eq('name', gameName)
  .single();

// If found, uses that game_titles entry
// If not found, creates new entry
```

### The Problem:
1. User A syncs "Edith Finch" PS5 version → Creates game_titles entry
2. User B syncs "Edith Finch" PS4 version → Finds existing entry, adds PS4 trophies
3. Now ONE entry has BOTH trophy lists merged
4. Users with PS4 version can earn PS5-only trophies and vice versa

## Impact

**Data Integrity:**
- Users credited with trophies they never earned
- Inflated platinum counts
- Wrong completion percentages
- Incorrect StatusXP calculations

**Scale:**
- Affects potentially EVERY user
- Affects hundreds of games
- Compounds over time as more users sync
- Recurs on every sync

## Proper Solution

### 1. Enhanced Game Matching
Games must be matched by BOTH name AND platform identifier:
```javascript
const existingGame = await supabase
  .from('game_titles')
  .select('*')
  .eq('name', gameName)
  .eq('platform_identifier', platformId) // NEW: PS4 vs PS5, etc.
  .single();
```

### 2. Database Schema Changes
Add platform version tracking:
```sql
ALTER TABLE game_titles 
ADD COLUMN platform_identifier TEXT; -- 'PS4', 'PS5', 'PS3_REMASTER', etc.

-- Create unique constraint
CREATE UNIQUE INDEX idx_game_titles_name_platform 
ON game_titles(name, platform_identifier);
```

### 3. Migration Strategy
Separate existing merged entries:
```sql
-- Find games with mixed platform trophies
-- Split into separate entries
-- Update user_games and user_achievements to point to correct entry
```

### 4. Sync Validation
Add checks during sync:
- Verify trophy count matches expected for that platform version
- Flag mismatches for manual review
- Prevent cross-version achievement assignment

## Temporary Workaround

Delete incorrect trophy entries manually:
```sql
-- Find and delete phantom achievements
DELETE FROM user_achievements
WHERE user_id = '<user_id>'
  AND achievement_id IN (
    -- IDs of achievements from wrong platform version
  );
```

## Next Steps

1. **Immediate:** Delete phantom trophies for affected users
2. **Short-term:** Add validation to prevent new cross-contamination
3. **Long-term:** Implement proper platform version tracking
4. **Migration:** Clean up existing merged entries

## Testing Requirements

- Test all cross-gen games (PS4/PS5 pairs)
- Test remastered games (PS3 → PS4)
- Test games with multiple editions (Standard/Definitive)
- Verify no phantom trophies after sync
- Verify correct game matching during sync

## Related Issues

- StatusXP calculation affected by phantom trophies
- Platinum count inflated
- Game completion stats incorrect
- Display Case may show wrong versions
- Flex Room may reference wrong game versions
