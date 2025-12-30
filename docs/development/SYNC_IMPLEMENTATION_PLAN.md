# Sync Consistency Implementation Plan

## Problem
Three platform syncs built inconsistently:
- **PSN**: ✅ Batch processing (5 games/call), auto-resume, works perfectly
- **Xbox**: ❌ All games in one call, times out, has 15-min cooldown
- **Steam**: ❌ All games in one call, times out at 58%

## Solution: Unified Batch Architecture

### Phase 1: Backend Standardization (Xbox & Steam)

#### Xbox Changes (`xbox-start-sync/index.ts`)
1. Remove 15-minute cooldown (not needed with batching)
2. Check `user_games` for already-synced games
3. Filter to unsynced or updated games
4. Process BATCH_SIZE=5 games per call
5. If more remain: status='pending', return
6. If complete: status='success', progress=100
7. Store last processed game cursor in metadata

#### Steam Changes (`steam-start-sync/index.ts`)
1. Check `user_games` for already-synced games
2. Filter to unsynced games
3. Process BATCH_SIZE=5 games per call
4. If more remain: status='pending', return
5. If complete: status='success', progress=100
6. Remove parallel batch processing (causes inconsistent state)

### Phase 2: Frontend Standardization (UI Screens)

#### Create Shared Sync Widget (`lib/ui/widgets/platform_sync_widget.dart`)
```dart
class PlatformSyncWidget {
  - Progress bar
  - Auto-polling when status='pending' (calls sync every 2s)
  - Stop button
  - Error display
  - Success message
  - Platform-specific branding (PSN blue, Xbox green, Steam gray)
}
```

#### Update All Sync Screens
- `psn_sync_screen.dart`: Use shared widget
- `xbox_sync_screen.dart`: Use shared widget, add auto-polling
- `steam_sync_screen.dart`: Use shared widget, add auto-polling

### Phase 3: Database Consistency

#### Add Sync Metadata Columns
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS xbox_sync_metadata JSONB;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS steam_sync_metadata JSONB;
```

Store in metadata:
- `last_processed_index`: Which game we're on
- `total_games`: Total count from API
- `processed_count`: How many done so far

### Implementation Order
1. ✅ Document architecture (this file)
2. ⏭️ Fix Xbox batch processing
3. ⏭️ Fix Steam batch processing  
4. ⏭️ Create shared UI widget
5. ⏭️ Update all three sync screens
6. ⏭️ Test all three platforms
7. ⏭️ Remove inconsistent features (Xbox cooldown)

## Expected Result
- User taps "Sync" on any platform
- Progress bar starts
- Backend processes 5 games
- Returns pending status
- UI auto-calls sync again after 2s
- Repeat until complete
- No manual intervention needed
- All three platforms work identically
