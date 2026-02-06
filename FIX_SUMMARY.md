# URGENT FIX: Achievement Icon Issues

## Problem Summary
1. **Database URLs point to WRONG bucket**: `/avatars/achievement-icons/` instead of `/achievement-icons/`
2. **Flutter code was using proxied URLs on mobile**: Mobile apps (iOS/Android) don't have CORS restrictions and should use direct external URLs, NOT proxied URLs from Supabase Storage

## Root Cause
- Previous chat session uploaded achievement icons to `/avatars/achievement-icons/` subfolder instead of the dedicated `/achievement-icons/` bucket
- This caused mobile apps to load user profile pictures (from avatars bucket) as achievement icons
- Web app also affected because proxied URLs pointed to wrong bucket

## Fixes Applied

### 1. Flutter Code Changes ✅ COMPLETED
Fixed all Flutter files to use `kIsWeb` platform detection:
- **Mobile (iOS/Android)**: Use `icon_url` (direct external URLs from PSN/Xbox/Steam)
- **Web**: Use `proxied_icon_url ?? icon_url` (proxied URLs for CORS, fallback to external)

Files fixed:
- `lib/ui/screens/game_achievements_screen.dart` - Achievement icon display
- `lib/ui/screens/game_browser_screen.dart` - Game cover display
- `lib/data/repositories/unified_games_repository.dart` - Unified games cover URLs
- `lib/data/repositories/trophy_room_repository.dart` - Trophy room icons/covers
- `lib/data/repositories/supabase_trophy_repository.dart` - Trophy icons
- `lib/data/repositories/supabase_game_repository.dart` - Game covers

### 2. Database URL Fix 🔴 NEEDS EXECUTION
Run `fix_proxied_url_bucket_path.sql` to correct the bucket path in database:
```sql
-- This will fix 152,156 achievement URLs
UPDATE achievements
SET proxied_icon_url = REPLACE(proxied_icon_url, '/avatars/achievement-icons/', '/achievement-icons/')
WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/%';
```

**IMPORTANT**: You MUST physically move the files in Supabase Storage from `/avatars/achievement-icons/` to `/achievement-icons/` bucket, or re-upload them to the correct bucket. Otherwise the URLs will point to non-existent files.

### 3. Additional Database Fixes 🔴 OPTIONAL
Run `fix_achievement_urls.sql` to fix the 49,794 achievements that have Supabase URLs in `icon_url` but missing `proxied_icon_url`:
```sql
UPDATE achievements
SET proxied_icon_url = icon_url
WHERE icon_url LIKE '%supabase%' AND proxied_icon_url IS NULL;
```

## Storage Migration Required
You need to move files in Supabase Storage:

**Option 1: Move Files (Recommended)**
1. Go to Supabase Dashboard → Storage → `avatars` bucket
2. Navigate to `achievement-icons/` subfolder
3. Download all files (psn/, steam/, etc.)
4. Go to `achievement-icons` bucket (top-level bucket, not subfolder)
5. Upload files to correct structure:
   - `achievement-icons/psn/`
   - `achievement-icons/steam/`
   - etc.
6. Delete the old `avatars/achievement-icons/` subfolder

**Option 2: Re-run Backfill (Slower)**
1. Delete all wrong URLs from database
2. Invoke backfill-achievement-icons Edge Function for each platform
3. This will re-download icons from external sources and upload to correct bucket

## Verification Steps
After running the SQL UPDATE and moving storage files:

1. Run verification query:
```sql
SELECT 
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/avatars/achievement-icons/%') as still_wrong,
    COUNT(*) FILTER (WHERE proxied_icon_url LIKE '%/achievement-icons/%' AND proxied_icon_url NOT LIKE '%/avatars/%') as now_correct
FROM achievements;
```

Expected result: `still_wrong = 0`, `now_correct = 152,156`

2. Test mobile app (iOS/Android):
   - Should show correct achievement icons from external URLs (PSN/Xbox/Steam CDNs)
   - Should NOT show user profile pictures

3. Test web app:
   - Should show correct achievement icons from Supabase Storage `/achievement-icons/` bucket
   - Should NOT have CORS errors (unless proxied_icon_url is NULL, then falls back to external URL)

## Data Statistics
- Total achievements: 216,780
- Achievements with WRONG bucket path: 152,156 (70%)
- Achievements with NULL proxied_icon_url: 62,837 (29%)
- Achievements needing icon_url → proxied_icon_url copy: 49,794 (23%)

## Platform Breakdown (using wrong bucket)
- Steam: 28,430 achievements (of 35,392 total = 80%)
- PlayStation: ~123,726 achievements

## Next Steps (Priority Order)
1. ✅ Flutter code fixes are DONE (committed/deployed)
2. 🔴 Run `fix_proxied_url_bucket_path.sql` UPDATE statement
3. 🔴 Move files in Supabase Storage from `/avatars/achievement-icons/` to `/achievement-icons/`
4. 🔴 Verify with SQL query
5. 🔴 Test mobile and web apps
6. 🟡 Optionally run `fix_achievement_urls.sql` for the 49,794 data integrity issues
7. 🟡 Review backfill-achievement-icons Edge Function to ensure future syncs use correct bucket
8. 🟡 Review sync functions (_shared/database.ts) to set proxied_icon_url during sync

## Critical Note
**NEVER use proxied URLs on mobile apps!** Mobile apps can load images from any domain without CORS restrictions. Only web apps need proxied URLs.
