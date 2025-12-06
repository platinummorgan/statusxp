# PSN Profile Integration - Implementation Summary

## Overview
Added PSN profile data fetching (onlineId, avatar, PS Plus status) to replace hardcoded usernames and add visual profile elements.

## Changes Made

### 1. Database Schema (`010_add_psn_profile_fields.sql`)
Added to `profiles` table:
- `psn_avatar_url` (text) - PSN avatar image URL
- `psn_is_plus` (boolean) - PlayStation Plus subscription status
- Existing `psn_online_id` now populated during sync

**Action Required**: Run `run_migration_manually.sql` in Supabase SQL Editor

### 2. PSN API (`_shared/psn-api.ts`)
- Added `PSNUserProfile` interface with onlineId, avatarUrls, plus status
- Added `getUserProfile()` function to fetch user profile data from PSN API
- Endpoint: `https://m.np.playstation.com/api/userProfile/v1/internal/users/{accountId}/profile2`

### 3. PSN Link Account Function (`psn-link-account/index.ts`)
- Now fetches both trophy summary AND user profile during account linking
- Stores `psn_online_id`, `psn_avatar_url`, `psn_is_plus` in profiles table
- Returns profile data in response for immediate UI feedback

**Status**: ✅ Deployed to Supabase

### 4. User Stats Domain Model (`lib/domain/user_stats.dart`)
Added fields:
- `avatarUrl` (String?, nullable)
- `isPsPlus` (bool, defaults to false)

Updated:
- Constructor
- `copyWith()`
- `fromJson()` / `toJson()`
- Equatable props

### 5. Repository (`lib/data/repositories/supabase_user_stats_repository.dart`)
- Fetches `psn_online_id`, `psn_avatar_url`, `psn_is_plus` from profiles
- **Username priority**: `psn_online_id` → fallback to `username` → fallback to "Player"
- This means PSN username automatically replaces manual username after sync

### 6. UI Components

#### New: `PsnAvatar` Widget (`lib/ui/widgets/psn_avatar.dart`)
- Circular avatar with neon cyan border and glow
- PS Plus badge overlay (bottom-right corner) when `isPsPlus == true`
- Badge: Blue circle with white "+" icon
- Fallback: Person icon if no avatar URL

#### Updated: Dashboard Screen (`lib/ui/screens/dashboard_screen.dart`)
- Added avatar to left of username (64px size)
- Layout: Row with `PsnAvatar` + username column
- Username now dynamically pulled from `psn_online_id` (not hardcoded)
- PS Plus badge shows automatically if user has subscription

### 7. Sample Data Updates
- Updated `sampleStats` to include `avatarUrl: null, isPsPlus: false`
- Updated `UserStatsCalculator` to set defaults for new fields

## User Experience Flow

### First Time (No PSN Link)
1. User signs up → `username` stored in profiles
2. Dashboard shows: Default avatar + manual username
3. No PS Plus badge

### After PSN Link
1. User links PSN account → Edge function fetches profile data
2. Database stores:
   - `psn_online_id`: "Dex-Morgan" (their actual PSN ID)
   - `psn_avatar_url`: "https://..."
   - `psn_is_plus`: true/false
3. Dashboard refreshes:
   - ✅ Real PSN avatar with neon border
   - ✅ PS Plus badge (if subscribed)
   - ✅ Real PSN username (replaces manual entry)

## Testing Checklist

### Database Migration
- [ ] Run `run_migration_manually.sql` in Supabase SQL Editor
- [ ] Verify columns exist: `psn_avatar_url`, `psn_is_plus`

### Edge Function
- [x] Deployed `psn-link-account` successfully
- [ ] Test PSN link flow in app
- [ ] Verify profile data appears in response

### Flutter App
- [ ] Hot restart app
- [ ] Check compile errors (should be none)
- [ ] View dashboard before PSN link (default avatar, manual username)
- [ ] Link PSN account
- [ ] View dashboard after sync (avatar loaded, username updated, Plus badge if applicable)

### Visual Verification
- [ ] Avatar displays with neon cyan glow
- [ ] PS Plus badge appears in bottom-right if user has Plus
- [ ] Username shows PSN ID (not hardcoded "Dex-Morgan")
- [ ] Layout looks balanced (avatar + name row)

## Known Issues
- Migration conflict with existing migrations (002, 003) - workaround: run SQL manually
- No avatar loading state (shows default icon immediately if URL fails)

## Future Enhancements
- Add avatar loading shimmer/spinner
- Cache avatars locally
- Add "Edit Profile" option to override PSN username
- Show PS Plus expiry date (requires additional API call)
- Add verified badge for officially verified accounts (`isOfficiallyVerified` field available)
