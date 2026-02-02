# Leaderboard Rank Movement Implementation

## Overview
This feature adds visual indicators (green ▲ up, red ▼ down arrows) next to leaderboard scores to show rank changes over time.

## Database Changes

### New Table: `leaderboard_history`
Stores historical snapshots of leaderboard rankings.

**Columns:**
- `user_id` (uuid) - User identifier
- `rank` (integer) - User's rank at snapshot time
- `total_statusxp` (bigint) - StatusXP points at snapshot time
- `total_game_entries` (integer) - Game count at snapshot time
- `snapshot_at` (timestamp) - When snapshot was taken

**Primary Key:** `(user_id, snapshot_at)`

**Indexes:**
- `idx_leaderboard_history_user_snapshot` - For efficient user history queries
- `idx_leaderboard_history_snapshot_at` - For finding latest snapshots

### New Functions

#### `snapshot_leaderboard()`
Creates a snapshot of the current leaderboard state.
- **When to call:** Daily at 3 AM UTC (via pg_cron)
- **What it does:** Saves current rank, StatusXP, and game count for all users on leaderboard
- **Usage:** `SELECT snapshot_leaderboard();`

#### `get_leaderboard_with_movement(limit_count, offset_count)`
Returns leaderboard with rank change information.

**Parameters:**
- `limit_count` (integer, default 100) - Number of results
- `offset_count` (integer, default 0) - Offset for pagination

**Returns:**
- `user_id` - User identifier
- `display_name` - User's display name
- `avatar_url` - Avatar URL (respects preferred platform)
- `total_statusxp` - Current StatusXP
- `total_game_entries` - Number of games
- `current_rank` - Current position on leaderboard
- `previous_rank` - Rank from last snapshot (null if new)
- `rank_change` - Difference (positive = moved up, negative = moved down, 0 = new/no change)
- `is_new` - Boolean indicating if user is new to leaderboard
- Platform-specific fields (psn, xbox, steam)

## How Rank Changes Work

### Calculation
```
rank_change = previous_rank - current_rank
```

**Examples:**
- Was rank 50, now rank 30: `rank_change = 20` (moved UP 20 spots) ✅ Green ▲
- Was rank 30, now rank 50: `rank_change = -20` (moved DOWN 20 spots) ❌ Red ▼
- New to leaderboard: `rank_change = 0`, `is_new = true` 🆕 NEW
- No change: `rank_change = 0`, `is_new = false` ➖

### Visual Indicators
- **Moved Up:** 🟢 Green arrow up (▲) + number
- **Moved Down:** 🔴 Red arrow down (▼) + number
- **New:** 🆕 "NEW" badge
- **No Change:** ➖ or no indicator

## Implementation Steps

### 1. Deploy Database Migration
```bash
# Apply migration
npx supabase db push

# Or via Supabase Dashboard
# Copy contents of 20260202000001_add_leaderboard_rank_tracking.sql
# Paste into SQL Editor and run
```

### 2. Create Initial Snapshot
The migration automatically creates the first snapshot. For subsequent snapshots:
```sql
SELECT snapshot_leaderboard();
```

### 3. Update Flutter App

#### Add to Leaderboard Model
```dart
class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final int totalStatusXp;
  final int totalGameEntries;
  final int currentRank;
  final int? previousRank;
  final int rankChange;
  final bool isNew;
  
  // Existing fields...
  
  LeaderboardMovement get movement {
    if (isNew) return LeaderboardMovement.new_;
    if (rankChange > 0) return LeaderboardMovement.up;
    if (rankChange < 0) return LeaderboardMovement.down;
    return LeaderboardMovement.noChange;
  }
}

enum LeaderboardMovement { up, down, noChange, new_ }
```

#### Update Leaderboard Query
Replace current query with:
```dart
final response = await supabase.rpc(
  'get_leaderboard_with_movement',
  params: {
    'limit_count': 100,
    'offset_count': 0,
  },
);
```

#### Display Movement Indicator
```dart
Widget buildMovementIndicator(LeaderboardEntry entry) {
  switch (entry.movement) {
    case LeaderboardMovement.up:
      return Row(
        children: [
          Icon(Icons.arrow_upward, color: Colors.green, size: 16),
          Text(
            '+${entry.rankChange}',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      );
    case LeaderboardMovement.down:
      return Row(
        children: [
          Icon(Icons.arrow_downward, color: Colors.red, size: 16),
          Text(
            '${entry.rankChange}',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      );
    case LeaderboardMovement.new_:
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10)),
      );
    case LeaderboardMovement.noChange:
      return SizedBox.shrink(); // Or show a dash
  }
}
```

### 4. Schedule Automatic Snapshots
The migration sets up a daily cron job at 3 AM UTC. Verify it's running:
```sql
SELECT * FROM cron.job WHERE jobname = 'daily-leaderboard-snapshot';
```

To manually trigger:
```sql
SELECT cron.run_job('daily-leaderboard-snapshot');
```

## Testing

### Test Queries
See `test_leaderboard_movement.sql` for comprehensive test queries including:
1. View leaderboard with movement indicators
2. Check specific user's movement
3. View snapshot history
4. Track user rank over time
5. See biggest movers
6. Create manual snapshots for testing

### Manual Testing Steps
1. Create initial snapshot: `SELECT snapshot_leaderboard();`
2. Wait a few minutes or modify some scores
3. Create second snapshot: `SELECT snapshot_leaderboard();`
4. Query: `SELECT * FROM get_leaderboard_with_movement(10, 0);`
5. Verify `rank_change` values are correct

### Production Rollout
1. Deploy migration to production
2. Initial snapshot will be created automatically
3. Monitor first 24 hours to ensure cron job runs
4. Update Flutter app to use new function
5. Deploy app update

## Monitoring

### Check Snapshot Health
```sql
-- How many snapshots exist?
SELECT COUNT(DISTINCT snapshot_at) FROM leaderboard_history;

-- When was last snapshot?
SELECT MAX(snapshot_at) FROM leaderboard_history;

-- How many users in latest snapshot?
SELECT COUNT(*) FROM leaderboard_history 
WHERE snapshot_at = (SELECT MAX(snapshot_at) FROM leaderboard_history);
```

### Cleanup Old Snapshots (Optional)
Keep last 90 days of snapshots:
```sql
DELETE FROM leaderboard_history 
WHERE snapshot_at < now() - INTERVAL '90 days';
```

## Performance Considerations

- **Snapshot size:** ~500 bytes per user per snapshot
- **100 users × 90 days:** ~4.5 MB
- **1000 users × 90 days:** ~45 MB
- Indexes ensure fast queries even with large history

## Rollback Plan

If issues occur, disable the feature:
```sql
-- Remove cron job
SELECT cron.unschedule('daily-leaderboard-snapshot');

-- Revert to old leaderboard query
-- Use original SELECT from leaderboard_cache

-- Optionally drop history table
-- DROP TABLE leaderboard_history;
```

## Future Enhancements

1. **Weekly/Monthly snapshots** - Add separate tables for different time periods
2. **Personal best indicators** - Show if user hit their highest rank ever
3. **Trend analysis** - Calculate if user is on upward/downward trend
4. **Notifications** - Alert users when they move significantly
5. **Historical charts** - Graph rank over time in profile
