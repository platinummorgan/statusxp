# Sync Process and Proxied Icons - Current State

## What Happens During Sync (Current Behavior)

### PSN Sync Flow:
1. **psn-start-sync** Edge Function calls Railway backend
2. Railway backend fetches trophies from PSN API
3. Railway backend inserts/updates achievements in database
4. ❌ **Only sets `icon_url`** (external PSN URL)
5. ❌ **Does NOT set `proxied_icon_url`**
6. ❌ **Does NOT download/upload icons to Storage**

### Result:
- `icon_url`: ✅ Set to PSN/Xbox/Steam CDN URL
- `proxied_icon_url`: ❌ NULL
- Mobile apps: ✅ Work (use icon_url directly)
- Web app: ⚠️ CORS errors on PS/Steam

## What SHOULD Happen (Fixed Behavior)

### Option 1: Sync Downloads Icons (RECOMMENDED)
**Pros:** Automatic, no manual backfill needed
**Cons:** Slower syncs (downloads images)

Flow:
1. PSN sync fetches trophies from API
2. For each trophy:
   - Set `icon_url` = external URL
   - Download icon from external URL
   - Upload to `/avatars/achievement-icons/psn/`
   - Set `proxied_icon_url` = Supabase Storage URL
3. Both mobile and web work perfectly

### Option 2: Sync Only Sets URLs, Manual Backfill Later
**Pros:** Fast syncs
**Cons:** Requires manual backfill step

Flow:
1. PSN sync sets `icon_url` only (fast)
2. User manually invokes backfill function
3. Backfill downloads and uploads icons
4. Sets `proxied_icon_url`

## Current Code Status

### ✅ FIXED - Flutter App
All 6 Dart files updated:
- Mobile: Uses `icon_url` (direct URLs)
- Web: Uses `proxied_icon_url ?? icon_url`

### ✅ FIXED - Backfill Function
`supabase/functions/backfill-achievement-icons/index.ts`:
- Uses platform code (psn/xbox/steam) ✅
- Uploads to `/avatars/achievement-icons/{platform}/` ✅
- Sets `proxied_icon_url` ✅

### ⚠️ PARTIALLY FIXED - Sync Helper
`supabase/functions/_shared/database.ts`:
- Added `downloadAndUploadIcon()` helper function ✅
- Updated `upsertTrophy()` to call helper ✅
- **BUT: This function may not be used by Railway backend** ⚠️

## Where Sync Actually Happens

The Edge Functions (`psn-start-sync`, `xbox-start-sync`, `steam-start-sync`) appear to trigger Railway backend, which directly inserts into database. The `_shared/database.ts` helper functions might not be used.

## Recommended Next Steps

### Immediate (Already Working):
1. ✅ Flutter apps work with current setup
2. ✅ Mobile: Uses external URLs (no CORS)
3. ⚠️ Web: Falls back to external URLs (CORS on PS/Steam)

### To Fix Web CORS:

**Option A: Add Icon Download to Railway Backend**
1. Find where Railway backend inserts achievements
2. Add logic to download icon and upload to Storage
3. Set `proxied_icon_url` during insert

**Option B: Run Manual Backfill**
1. Deploy fixed backfill function:
   ```bash
   supabase functions deploy backfill-achievement-icons
   ```
2. Invoke for PlayStation platforms:
   ```bash
   curl -X POST https://your-project.supabase.co/functions/v1/backfill-achievement-icons \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -d '{"platform_ids": [1, 2, 5, 9], "batch_size": 100, "table": "achievements"}'
   ```
3. Repeat for Steam if needed:
   ```bash
   curl -d '{"platform_ids": [4], "batch_size": 100, "table": "achievements"}'
   ```

## Files Modified

1. ✅ `lib/ui/screens/game_achievements_screen.dart` - Platform-specific URLs
2. ✅ `lib/ui/screens/game_browser_screen.dart` - Platform-specific URLs
3. ✅ `lib/data/repositories/*.dart` (4 files) - Platform-specific URLs
4. ✅ `supabase/functions/backfill-achievement-icons/index.ts` - Fixed paths
5. ⚠️ `supabase/functions/_shared/database.ts` - Added helper (may not be used)

## Summary

**Current State:** Apps work, but web has CORS on PS/Steam icons.

**To Fully Fix:** Either modify Railway backend to download icons during sync, OR run manual backfill with the fixed function.

**Recommendation:** Run manual backfill now for quick fix, then update Railway backend for future syncs.
