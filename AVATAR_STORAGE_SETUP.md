# Avatar Storage Setup Guide

## Problem Solved
External avatar URLs from PSN, Xbox, and Steam CDNs are blocked by CORS policy when accessed from statusxp.com. This prevents avatars from displaying on the web version of the app.

**CORS Error Example:**
```
Access to XMLHttpRequest at 'https://psn-rsc.prod.dl.playstation.net/...' 
from origin 'https://statusxp.com' has been blocked by CORS policy: 
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

## Solution
Download external platform avatars server-side and store them in Supabase Storage under the StatusXP domain. This way:
1. Avatars are served from `statusxp.supabase.co` (same origin)
2. No CORS issues
3. Faster loading (cached by Supabase CDN)
4. Better control over avatar content

## Supabase Storage Bucket Setup

### Step 1: Create the Avatars Bucket
1. Go to Supabase Dashboard → Storage
2. Click "Create a new bucket"
3. Bucket name: `avatars`
4. Set to **Public** (important for displaying images)
5. Click "Create bucket"

### Step 2: Configure Bucket Settings
1. Click on the `avatars` bucket
2. Go to "Policies" tab
3. Ensure "Public access" is enabled for reading
4. Create a policy for public SELECT if not already present:
   ```sql
   CREATE POLICY "Public avatar read access"
   ON storage.objects FOR SELECT
   USING (bucket_id = 'avatars');
   ```

### Step 3: Optional - Set Up File Lifecycle
To prevent storage from growing indefinitely, you can set up automatic cleanup:
1. In bucket settings → "Lifecycle"
2. Add rule: Delete files older than 180 days (6 months)
3. This ensures outdated avatars are removed when users update their profiles

## Implementation Details

### Files Modified

#### 1. Supabase Edge Function (PSN)
**File:** `supabase/functions/psn-link-account/index.ts`
- Downloads PSN avatar URL received from PSN API
- Uploads to Supabase Storage `avatars/psn/` folder
- Saves Supabase URL to `psn_avatar_url` field

#### 2. Xbox Sync Service
**File:** `sync-service/xbox-sync.js`
- Downloads Xbox avatar during token refresh
- Uploads to Supabase Storage `avatars/xbox/` folder  
- Saves Supabase URL to `xbox_avatar_url` field

#### 3. Steam Sync Service
**File:** `sync-service/steam-sync.js`
- Downloads Steam avatar from Steam API
- Uploads to Supabase Storage `avatars/steam/` folder
- Saves Supabase URL to `steam_avatar_url` field

### Helper Functions Created

#### Deno (Edge Functions)
**File:** `supabase/functions/_shared/avatar-storage.ts`
- `uploadExternalAvatar()` - Downloads and uploads avatar
- `deleteAvatar()` - Removes avatar from storage

#### Node.js (Sync Service)
Added to both `xbox-sync.js` and `steam-sync.js`:
- `uploadExternalAvatar()` - Same functionality as Deno version

### Storage Structure
```
avatars/
├── psn/
│   ├── user-id-123_1234567890.jpg
│   └── user-id-456_1234567891.png
├── xbox/
│   ├── user-id-123_1234567892.jpg
│   └── user-id-789_1234567893.png
└── steam/
    ├── user-id-123_1234567894.jpg
    └── user-id-321_1234567895.jpg
```

## When Avatars Are Proxied

### PSN Avatars
- **Timing:** When user links their PSN account for the first time
- **Location:** PSN Link Account Edge Function
- **Trigger:** User enters NPSSO token and clicks "Link Account"

### Xbox Avatars
- **Timing:** During Xbox token refresh (initial link or token renewal)
- **Location:** Xbox Sync Service - Token Refresh
- **Trigger:** Automatic during sync operations

### Steam Avatars
- **Timing:** At the start of every Steam sync
- **Location:** Steam Sync Service - Initial Profile Fetch
- **Trigger:** User initiates Steam sync

## Database Fields
No schema changes needed! The same fields are used:
- `profiles.psn_avatar_url` - Now stores Supabase URL instead of PSN URL
- `profiles.xbox_avatar_url` - Now stores Supabase URL instead of Xbox URL
- `profiles.steam_avatar_url` - Now stores Supabase URL instead of Steam URL

## Migration Plan for Existing Users

### Option 1: Gradual Migration (Recommended)
- Existing users keep their external avatar URLs
- Next time they sync their platform, avatar will be proxied
- No immediate action needed

### Option 2: One-Time Migration
If you want to migrate existing users immediately:
```sql
-- This would require a script to:
-- 1. Fetch all profiles with external avatar URLs
-- 2. Download each avatar
-- 3. Upload to Supabase Storage
-- 4. Update the database with new URLs
```

## Testing

### After Setup
1. Create the `avatars` bucket in Supabase
2. Ensure public read access is enabled
3. Link a new PSN account (or any platform)
4. Check the Supabase Storage browser - you should see a new file under `avatars/psn/`
5. Visit statusxp.com and verify avatar displays without CORS errors
6. Check browser console - no more red CORS errors!

### Verification Checklist
- [ ] `avatars` bucket created in Supabase
- [ ] Bucket is set to Public
- [ ] Public read policy exists
- [ ] PSN link function deployed to Supabase
- [ ] Xbox sync service restarted (if running on Railway/server)
- [ ] Steam sync service restarted (if running on Railway/server)
- [ ] Test linking a new PSN account
- [ ] Verify avatar appears on web without CORS error
- [ ] Check Supabase Storage - confirm file was uploaded

## Troubleshooting

### Avatar not uploading
Check logs for `[AVATAR STORAGE]` messages:
- `Downloading [platform] avatar from: [url]` - Started download
- `Uploading to Supabase Storage: [filename]` - Started upload
- `Successfully uploaded avatar: [url]` - Success!
- `Failed to download avatar: [status]` - External URL unreachable
- `Upload error: [error]` - Supabase Storage issue (check bucket exists and is public)

### Still seeing CORS errors
- Verify the avatar URL in database starts with your Supabase URL
- Check that the bucket is truly set to Public
- Ensure the public read policy exists
- Try clearing browser cache

### Old avatars piling up
- Set up lifecycle rules to auto-delete old files
- Or manually clean up old avatars periodically
- Each user should only have 1 avatar per platform (latest upload)

## Benefits
✅ No more CORS errors on web  
✅ Faster avatar loading (Supabase CDN)  
✅ Works across all platforms (PSN, Xbox, Steam)  
✅ Automatic for all new account links  
✅ No database schema changes needed  
✅ Fallback to external URL if upload fails  
