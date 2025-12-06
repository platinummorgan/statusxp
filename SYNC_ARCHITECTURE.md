# Unified Sync Architecture

## Core Principles
All platform syncs (PSN, Xbox, Steam) follow the SAME pattern:

### 1. Batch Processing
- Process games in small batches (5-10 games per function call)
- Edge Functions have ~2 minute timeout - must complete within that
- Auto-resume on next sync call if more games remain

### 2. Status Flow
```
NULL → pending → success
       ↓
     stopped (manual)
       ↓
     error (failure)
```

### 3. Progress Tracking
- `{platform}_sync_status`: Current state
- `{platform}_sync_progress`: 0-100 percentage
- `{platform}_sync_error`: Error message if failed
- `last_{platform}_sync_at`: Timestamp of last successful sync

### 4. Sync Resume Logic
1. Get all games from platform API
2. Check which games already synced (exist in `user_games`)
3. Filter to unsynced games OR games with updates
4. Take next BATCH_SIZE games
5. Process batch
6. If more games remain: status = 'pending', return for next call
7. If complete: status = 'success', progress = 100

### 5. UI Auto-Polling
- When status = 'pending', UI auto-calls sync again after 2 seconds
- User sees continuous progress bar
- No manual "Continue Sync" button needed
- Optional "Stop Sync" button sets status = 'stopped'

## Implementation Checklist

### Backend (Edge Functions)
- [ ] `{platform}-start-sync`: Batch processing with resume
- [ ] `{platform}-sync-status`: Return current status
- [ ] `{platform}-stop-sync`: Set status to 'stopped'

### Frontend (Dart/Flutter)
- [ ] Sync screen with progress bar
- [ ] Auto-polling when status = 'pending'
- [ ] Stop sync button
- [ ] Error display
- [ ] Success message

### Database
- [ ] Consistent column naming across platforms
- [ ] Track synced games to avoid re-processing
- [ ] Update only changed data (not full overwrites)

## File Structure
```
supabase/functions/
├── psn-start-sync/          ✅ Has batch system
├── xbox-start-sync/         ❌ Needs batch system
├── steam-start-sync/        ❌ Needs batch system
└── _shared/
    └── sync-helpers.ts      📝 TODO: Shared batch logic

lib/ui/screens/
├── psn/psn_sync_screen.dart     ✅ Has auto-polling
├── xbox/xbox_sync_screen.dart   ❌ Needs auto-polling
└── steam/steam_sync_screen.dart ❌ Needs auto-polling
```

## Next Steps
1. Extract PSN batch logic to shared helper
2. Apply to Xbox sync (with Xbox-specific API calls)
3. Apply to Steam sync (with Steam-specific API calls)
4. Unify UI sync screens (shared widget component)
5. Test all three platforms for consistency
