# PlayStation Network Integration

This document describes the PSN trophy import system for StatusXP.

## Overview

The PSN integration allows users to:
1. Link their PlayStation Network account via in-app OAuth
2. Automatically import all trophy data
3. Sync progress regularly
4. View trophies from PS3, PS4, PS5, and PS Vita

## Architecture

### Components

1. **Database Schema** (`supabase/migrations/005_psn_integration.sql`)
   - Extended `profiles` table with PSN credentials and sync status
   - Added PSN-specific columns to `game_titles` and `trophies`
   - New tables: `psn_sync_log`, `psn_trophy_groups`, `psn_user_trophy_profile`

2. **Edge Functions** (`supabase/functions/`)
   - `psn-link-account`: Exchanges NPSSO token for PSN credentials
   - `psn-start-sync`: Begins trophy data import
   - `psn-sync-status`: Returns current sync progress
   - `_shared/psn-api.ts`: PSN API client implementation
   - `_shared/database.ts`: Database helper functions

3. **Flutter Service** (`lib/data/psn_service.dart`)
   - `PSNService`: Calls Edge Functions
   - `PSNSyncStatus`: Real-time sync status model
   - Stream-based status updates

4. **UI Screens** (`lib/ui/screens/psn/`)
   - `PSNConnectScreen`: Simple "Sign in with PlayStation" button
   - `PSNWebViewLoginScreen`: In-app OAuth browser for Sony login
   - `PSNSyncScreen`: Manage and monitor trophy syncs

## User Flow (WebView OAuth)

### 1. Link PSN Account (Like PS Trophies App)

```
User opens PSN Sync screen
  ↓
Taps "Link PSN Account"
  ↓
Opens PSNConnectScreen
  ↓
User taps "Sign in with PlayStation" button
  ↓
Opens PSNWebViewLoginScreen (in-app browser)
  ↓
Sony's official login page loads in WebView
  ↓
User enters PlayStation credentials securely on Sony's site
  ↓
After successful login, user taps "Complete Sign In"
  ↓
WebView navigates to ca.account.sony.com/api/v1/ssocookie
  ↓
WebView automatically extracts NPSSO token from JSON response
  ↓
Returns NPSSO to PSNConnectScreen
  ↓
App calls psn-link-account Edge Function
  ↓
Edge Function:
  - Exchanges NPSSO for access code
  - Exchanges access code for auth tokens
  - Fetches PSN profile summary
  - Stores credentials in profiles table
  ↓
Success! Account linked
  ↓
User returned to PSNSyncScreen
```

**Key Benefits:**
- ✅ User NEVER enters PSN password in the app
- ✅ Login happens on Sony's official website
- ✅ One-tap experience (tap "Sign in", login, done)
- ✅ Automatic token extraction
- ✅ No manual copy/paste required
- ✅ Same UX as PS Trophies app

### 2. Sync Trophies

```
User taps "Sync Now"
  ↓
App calls psn-start-sync Edge Function
  ↓
Edge Function starts background process:
  1. Refresh access token if needed
  2. Fetch user's game list from PSN
  3. For each game:
     - Insert/update game_titles
     - Insert/update user_games
     - Fetch trophy groups
     - Fetch all trophies
     - Fetch user's earned trophies
     - Insert/update trophies
     - Insert/update user_trophies
  4. Recalculate user stats
  5. Update sync status
  ↓
UI polls sync status every 2 seconds
  ↓
Shows progress: "Processing game 15 of 127..."
  ↓
Sync completes
  ↓
Dashboard refreshes with new data
```

## Database Schema

### profiles (extended)
- `psn_account_id`: PSN account ID
- `psn_npsso_token`: Encrypted NPSSO (for future re-auth)
- `psn_access_token`: Current API access token
- `psn_refresh_token`: Refresh token
- `psn_token_expires_at`: Token expiry timestamp
- `last_psn_sync_at`: Last successful sync
- `psn_sync_status`: `never_synced | pending | syncing | success | error`
- `psn_sync_error`: Error message if failed
- `psn_sync_progress`: Percentage (0-100)

### game_titles (extended)
- `psn_np_communication_id`: PSN unique ID for trophy retrieval
- `psn_np_title_id`: PSN title ID (CUSA/PPSA format)
- `psn_np_service_name`: `trophy` (PS3/4/Vita) or `trophy2` (PS5)
- `psn_trophy_set_version`: Version of trophy set
- `psn_has_trophy_groups`: Whether game has DLC groups

### trophies (extended)
- `psn_trophy_id`: Trophy ID within game
- `psn_trophy_group_id`: Trophy group (default, 001, 002...)
- `psn_trophy_type`: bronze, silver, gold, platinum
- `psn_is_secret`: Hidden trophy flag
- `psn_earn_rate`: Global earn percentage

### psn_sync_log (new)
Tracks all sync operations with detailed statistics.

### psn_trophy_groups (new)
Stores DLC trophy group metadata.

### psn_user_trophy_profile (new)
Stores PSN account trophy level and tier.

## PSN API

Based on the `psn-api` library patterns. Key endpoints:

### Authentication
- `POST /oauth/authorize` - Exchange NPSSO for access code
- `POST /oauth/token` - Exchange access code for tokens
- `POST /oauth/token` (refresh) - Refresh access token

### Trophy Data
- `GET /trophy/v1/users/{accountId}/trophySummary` - Profile summary
- `GET /trophy/v1/users/{accountId}/trophyTitles` - Game list
- `GET /trophy/v1/npCommunicationIds/{id}/trophyGroups` - Trophy groups
- `GET /trophy/v1/npCommunicationIds/{id}/trophyGroups/{groupId}/trophies` - Trophy list
- `GET /trophy/v1/users/{accountId}/npCommunicationIds/{id}/trophyGroups/{groupId}/trophies` - Earned trophies

## Deployment

### 1. Apply Database Migration

```bash
cd supabase
supabase db push
```

### 2. Deploy Edge Functions

```bash
supabase functions deploy psn-link-account
supabase functions deploy psn-start-sync
supabase functions deploy psn-sync-status
```

### 3. Set Environment Variables (if needed)

Edge Functions automatically have access to:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`

## Security Considerations

### NPSSO Token Storage
- **Current**: Stored in plain text in `profiles.psn_npsso_token`
- **Production**: Should be encrypted at rest using Supabase Vault
- **Recommendation**: Use `pgsodium` extension for encryption

### Access Token Refresh
- Tokens expire after ~1 hour
- Automatically refreshed before sync operations
- Refresh tokens valid for ~60 days

### Row Level Security
Ensure RLS policies prevent users from accessing other users' PSN data:

```sql
-- Only allow users to read their own PSN data
CREATE POLICY "Users can view own PSN data"
  ON profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Only allow users to update their own PSN credentials
CREATE POLICY "Users can update own PSN data"
  ON profiles
  FOR UPDATE
  USING (auth.uid() = id);
```

## Rate Limiting

PSN API has undocumented rate limits. Current implementation:
- 100ms delay between game processing
- Batch size: 800 games per request
- Trophy batch size: 100 trophies per request

If rate limited, the sync will fail with an error. User can retry after waiting.

## Testing

### Unit Tests
```dart
// Test PSN service
test('linkAccount stores credentials', () async {
  final service = PSNService(mockClient);
  final result = await service.linkAccount('mock-npsso');
  expect(result.success, true);
});

// Test sync status parsing
test('PSNSyncStatus.fromJson parses correctly', () {
  final json = {
    'isLinked': true,
    'status': 'syncing',
    'progress': 45,
  };
  final status = PSNSyncStatus.fromJson(json);
  expect(status.isSyncing, true);
  expect(status.progress, 45);
});
```

### Integration Tests
```dart
testWidgets('PSN sync flow', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Navigate to PSN sync
  await tester.tap(find.byIcon(Icons.cloud_sync));
  await tester.pumpAndSettle();
  
  // Link account
  await tester.tap(find.text('Link PSN Account'));
  await tester.pumpAndSettle();
  
  // Enter NPSSO
  await tester.enterText(find.byType(TextField), 'test-npsso');
  await tester.tap(find.text('Link PSN Account'));
  await tester.pumpAndSettle();
  
  // Verify success
  expect(find.text('Successfully linked'), findsOneWidget);
});
```

## Troubleshooting

### "Invalid NPSSO token"
- Token may have expired (expires after ~2 months)
- User may have signed out on PSN website
- Solution: Get a fresh NPSSO token

### "Sync stuck at X%"
- Check Edge Function logs in Supabase dashboard
- Verify access token hasn't expired
- Check for rate limiting errors

### "Games not appearing"
- Verify games have been played at least once on PSN
- Check if game is delisted (may not sync properly)
- Verify psn_sync_status = 'success'

### Missing Trophies
- Some trophies may be hidden/secret
- DLC trophies may be in separate groups
- Check `psn_trophy_groups` table for DLC data

## Future Enhancements

1. **Incremental Sync**
   - Only fetch games modified since last sync
   - Use `lastUpdatedDateTime` from API

2. **Background Sync**
   - Automatic daily sync
   - Cron job or scheduled Edge Function

3. **Real-time Updates**
   - WebSocket connection for live progress
   - No polling needed

4. **Multi-account Support**
   - Link multiple PSN accounts
   - Aggregate trophies across accounts

5. **Trophy Rarity Calculations**
   - Store global earn rates
   - Calculate personal rarity rankings

## API Reference

### Flutter Service

```dart
final psnService = ref.read(psnServiceProvider);

// Link account
final result = await psnService.linkAccount('npsso-token');

// Start sync
await psnService.startSync(syncType: 'full');

// Get status
final status = await psnService.getSyncStatus();

// Watch status (stream)
ref.watch(psnSyncStatusProvider).when(
  data: (status) => Text(status.status),
  loading: () => CircularProgressIndicator(),
  error: (e, _) => Text('Error: $e'),
);
```

### Edge Functions

```typescript
// Link account
POST /psn-link-account
Body: { "npssoToken": "..." }
Response: {
  "success": true,
  "accountId": "...",
  "trophyLevel": 350,
  "totalTrophies": 5230
}

// Start sync
POST /psn-start-sync
Body: { "syncType": "full" }
Response: {
  "success": true,
  "syncLogId": 123,
  "message": "Sync started"
}

// Get status
GET /psn-sync-status
Response: {
  "isLinked": true,
  "status": "syncing",
  "progress": 45,
  "lastSyncText": "2 hours ago",
  "latestLog": { ... }
}
```

## References

- PSN API Library: https://github.com/achievements-app/psn-api
- NPSSO Guide: https://psn-api.achievements.app/authentication/authenticating-manually
- PlayStation Trophy Tiers: https://andshrew.github.io/PlayStation-Trophies/
