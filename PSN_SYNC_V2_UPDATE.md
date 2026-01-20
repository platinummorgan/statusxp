# PSN Sync V2 Schema Update

## Changes Made

Updated `sync-service/psn-sync.js` to write to V2 schema tables with composite primary keys.

### Database Table Changes

| Old Table (V1) | New Table (V2) | Key Changes |
|----------------|----------------|-------------|
| `game_titles` | `games` | Added `platform_id=1` (PSN), use `platform_game_id` as natural key |
| `user_games` | `user_progress` | Added composite key `(user_id, platform_id, platform_game_id)` |
| `achievements` | `achievements` | Added composite key `(platform_id, platform_game_id, platform_achievement_id)` |
| `user_achievements` | `user_achievements` | Added composite key `(user_id, platform_id, platform_game_id, platform_achievement_id)` |

### Column Mapping

#### user_progress (formerly user_games)
- `game_title_id` → `platform_game_id` (now part of composite key with `platform_id`)
- `earned_trophies` → `achievements_earned`
- `total_trophies` → `total_achievements`
- `last_trophy_earned_at` → `last_achievement_earned_at`
- Trophy counts moved to `metadata` JSONB: `bronze_trophies`, `silver_trophies`, `gold_trophies`, `platinum_trophies`, `has_platinum`

#### games (formerly game_titles)
- Uses `platform_id=1` for all PSN games
- Uses `platform_game_id` = PSN `npCommunicationId` (NPWR ID)
- Removed dedicated `psn_npwr_id` column (now uses `platform_game_id`)

#### achievements
- `game_title_id` → composite key with `platform_id` + `platform_game_id`
- `platform` column removed (replaced by `platform_id=1`)
- Added `base_status_xp` (calculated from `rarity_global`: 10/13/18/23/30)
- Added `rarity_multiplier` (calculated from `rarity_global`: 1.00/1.25/1.75/2.25/3.00)
- Platform-specific data moved to `metadata` JSONB: `trophy_type`, `platform_version`, `is_dlc`, `dlc_name`

## How to Test

### 1. Start the Sync Service
```powershell
cd sync-service
node psn-sync.js
```

### 2. Trigger a PSN Sync
In your Flutter app, trigger a PSN sync for your account.

### 3. Verify Data in Database

#### Check games table
```sql
SELECT 
  platform_id, 
  platform_game_id, 
  name, 
  cover_url,
  metadata
FROM games 
WHERE platform_id = 1 -- PSN
ORDER BY name
LIMIT 10;
```

Expected: New PSN games appear with `platform_id=1` and `platform_game_id` set to NPWR ID.

#### Check user_progress table
```sql
SELECT 
  user_id,
  platform_id,
  platform_game_id,
  achievements_earned,
  total_achievements,
  completion_percent,
  metadata
FROM user_progress
WHERE user_id = '<your-user-id>' AND platform_id = 1
ORDER BY last_played_at DESC
LIMIT 10;
```

Expected: Your PSN games appear with correct achievement counts and metadata containing trophy breakdowns.

#### Check achievements table
```sql
SELECT 
  platform_id,
  platform_game_id,
  platform_achievement_id,
  name,
  rarity_global,
  base_status_xp,
  rarity_multiplier,
  is_platinum,
  include_in_score,
  metadata
FROM achievements
WHERE platform_id = 1 AND platform_game_id = '<game-npwr-id>'
LIMIT 10;
```

Expected: Achievements have correct `base_status_xp` values:
- Common (>25%): 10 XP
- Uncommon (10-25%): 13 XP  
- Rare (5-10%): 18 XP
- Very Rare (1-5%): 23 XP
- Ultra Rare (≤1%): 30 XP
- Platinum: 0 XP (include_in_score=false)

#### Check user_achievements table
```sql
SELECT 
  user_id,
  platform_id,
  platform_game_id,
  platform_achievement_id,
  earned_at
FROM user_achievements
WHERE user_id = '<your-user-id>' AND platform_id = 1
LIMIT 10;
```

Expected: Your earned PSN achievements appear with composite keys.

### 4. Verify in App

1. **Browse Games**: Go to "Browse All Games" → Filter by PlayStation → Should show your PSN games with cover images
2. **My Games**: Should show your PSN games with achievement counts
3. **Game Details**: Click on a PSN game → Should show all trophies with rarity percentages
4. **Earned Achievements**: Earned trophies should be marked with earned date

### 5. Check for Errors

Monitor the sync service logs for any errors:
```powershell
# Look for these success indicators:
# ✅ Platform resolved from cache: PS5 → ID 1
# 🔄 NEW: [Game Name] (earned: X)
# [PSN RARITY] [Trophy Name]: X.XX%
```

Look for these error patterns:
```powershell
# ❌ Failed to update game cover
# ❌ Failed to fetch trophies for [Game Name]
# ❌ Error processing title [Game Name]
```

## Success Criteria

✅ PSN games appear in `games` table with `platform_id=1`  
✅ User progress tracked in `user_progress` with composite keys  
✅ Achievements stored with correct `base_status_xp` values  
✅ No duplicate entries (composite keys prevent duplicates)  
✅ Cover images display in "Browse Games"  
✅ Trophy details display in "Game Details"  
✅ StatusXP calculations can use `base_status_xp` directly  

## Rollback Plan

If sync fails, you can:
1. Stop the sync service
2. Check database for partial data
3. Delete test data if needed:
```sql
-- Delete test sync data (BE CAREFUL - THIS DELETES DATA!)
DELETE FROM user_achievements WHERE user_id = '<test-user-id>' AND platform_id = 1;
DELETE FROM user_progress WHERE user_id = '<test-user-id>' AND platform_id = 1;
-- Games and achievements can stay (shared across users)
```

## Next Steps After Testing

1. If PSN sync works: Update Xbox sync (platform_ids: 10=360, 11=One, 12=SeriesX)
2. If PSN sync works: Update Steam sync (platform_id: 5)
3. Once all syncs work: Apply StatusXP calculation function
4. Test full sync with all platforms
5. Release emergency app update to production
