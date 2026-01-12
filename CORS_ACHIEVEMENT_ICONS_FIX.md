# Fix CORS Issues with Achievement/Trophy Icons

## Problem
PlayStation's image API (image.api.playstation.com) blocks cross-origin requests from browsers, causing CORS errors when displaying trophy/achievement icons on the web.

## Solution
Proxy achievement icons through Supabase Storage, similar to how game covers are already proxied.

## Steps to Deploy

### 1. Add Database Column
Run this SQL in your Supabase SQL editor:
```bash
# Copy to clipboard and run in Supabase
cat add_proxied_icon_url_column.sql
```

This adds `proxied_icon_url` columns to both `achievements` and `trophies` tables.

### 2. Migrate Existing Icons
Run the migration script to copy existing achievement icons to Supabase Storage:

```bash
cd sync-service
node migrate-achievement-icons.js
```

**Note:** The script processes 100 achievements per run. If you have more than 100 achievements with icons, run it multiple times until complete.

### 3. Update Sync Service
Future syncs should automatically store icons in Supabase Storage. Update your PSN/Xbox/Steam sync scripts to:

1. Download the external icon URL
2. Upload to Supabase Storage `avatars/achievement-icons/{platform}/{achievementId}_{timestamp}.{ext}`
3. Store the public URL in `proxied_icon_url` column

Example pattern (from migrate-game-covers.js):
```javascript
const response = await fetch(externalIconUrl);
const arrayBuffer = await response.arrayBuffer();

const filename = `achievement-icons/${platform}/${achievementId}_${Date.now()}.png`;

const { data } = await supabase.storage
  .from('avatars')
  .upload(filename, arrayBuffer, { contentType: 'image/png', upsert: true });

const { data: { publicUrl } } = supabase.storage
  .from('avatars')
  .getPublicUrl(filename);

// Store publicUrl in proxied_icon_url column
```

### 4. Web Build Already Deployed
The Flutter web build has been updated to use `COALESCE(proxied_icon_url, icon_url)` in all queries, so it will:
- Use proxied URL when available (no CORS issues)
- Fall back to original URL if not yet migrated

Changed files:
- `lib/ui/screens/game_achievements_screen.dart` - Achievement detail screen
- `lib/features/display_case/repositories/display_case_repository.dart` - Trophy display case
- `lib/data/repositories/trophy_room_repository.dart` - Trophy room queries

### 5. Monitor Migration Progress
Check how many icons still need proxying:
```sql
SELECT 
  platform,
  COUNT(*) FILTER (WHERE icon_url IS NOT NULL) as total_with_icons,
  COUNT(*) FILTER (WHERE proxied_icon_url IS NOT NULL) as proxied,
  COUNT(*) FILTER (WHERE icon_url IS NOT NULL AND proxied_icon_url IS NULL) as needs_proxying
FROM achievements
GROUP BY platform;
```

## Verification
1. Open https://statusxp.com in browser
2. Navigate to a game's achievements page
3. Open Chrome DevTools Console (F12)
4. Look for:
   - ❌ Before: CORS errors from `image.api.playstation.com`
   - ✅ After: Images loading from `supabase.co/storage/v1/object/public/avatars/achievement-icons/`

## Benefits
- No more CORS errors on web
- Faster image loading (cached in Supabase CDN)
- Works on mobile too (though mobile apps don't have CORS restrictions)
- Consistent with existing game cover proxying infrastructure
