# Fixed Issues Archive

This document tracks issues that have been resolved, providing historical context for fixes and debugging patterns.

## January 24, 2026

### Critical Issue #1: Steam User Not Appearing on Leaderboard ✅
**Problem:** New user uploaded Steam profile but doesn't appear on StatusXP leaderboard (Steam-only user).

**Root Cause:** Leaderboard population requires:
- `show_on_leaderboard = true` flag (default for new users)
- `merged_into_user_id IS NULL`
- Achievements with `include_in_score = true`
- `refresh_statusxp_leaderboard()` must be called after sync

**Status:** System already configured correctly. Sync services automatically call `refresh_statusxp_leaderboard()` after syncing. User should appear on leaderboard after their first successful Steam sync completes.

---

### Critical Issue #2: Steam Sync Screen Text Visibility ✅
**Problem:** Light text on white background in Steam API instruction section was unreadable.

**Solution:** 
- Updated `lib/ui/widgets/platform_sync_widget.dart`
- Changed text color to `Colors.grey[800]` for high contrast
- Added explicit font size (14px) and line height (1.4)
- Made bullet points bold and more visible

**Files Modified:**
- `lib/ui/widgets/platform_sync_widget.dart` (line 222-236)

---

### Critical Issue #3: Password Reset Feature ✅
**Problem:** No password reset functionality for users who forgot their password.

**Solution Implemented:**
1. **UI Enhancement:**
   - Added "Forgot your password?" link on main sign-in screen (visible to all users including OAuth users)
   - Added "Forgot Password?" link in email/password sheet (for convenience)
   - Shows dialog to collect email address and send reset link

2. **Backend Already Existed:**
   - `lib/data/auth/auth_service.dart` has `resetPassword()` method
   - Uses Supabase's `resetPasswordForEmail`
   - Deep link configured: `com.statusxp.statusxp://reset-password`

3. **Password Reset Screen:**
   - `lib/ui/screens/auth/reset_password_screen.dart` (already existed)
   - Complete password reset UI with validation
   - Password visibility toggles
   - Proper error handling

4. **Deep Link Configuration:**
   - iOS: `com.statusxp.statusxp` scheme in Info.plist ✅
   - Android: Intent filters in AndroidManifest.xml ✅
   - Supabase: Redirect URL configured ✅
   - Router: `/reset-password` route in app_router.dart ✅
   - Main.dart: Deep link handling implemented ✅

**Files Modified:**
- `lib/ui/screens/auth/sign_in_screen.dart` (added forgot password UI and dialog method)

**Configuration Verified:**
- Supabase redirect URLs include `com.statusxp.statusxp://reset-password`
- iOS Info.plist has URL scheme configured
- Android AndroidManifest.xml has intent filters
- Deep link handling works on iOS, Android, and Web

**User Flow:**
1. User clicks "Forgot your password?" on sign-in screen
2. Enters email in dialog
3. Receives password reset email from Supabase
4. Clicks link in email → App opens to reset screen (deep link)
5. Enters new password → Password updated
6. User signs out → Signs back in with new password

---

## January 21, 2026
**FIXED:**
✅ Hardcoded user ID - NOW FIXED! Uses `currentUserIdProvider` which pulls from Supabase auth
   - `lib/state/statusxp_providers.dart` correctly uses `authService.currentUser?.id`
   - All screens (flex_room, leaderboard, achievements) use this provider
✅ Edge function `delete-account` - DEPLOYED and working (integrated in auth_service.dart)
   - Called from Settings → Delete Account
   - Required for Apple App Store compliance


## January 22, 2026

### Issue #6: My Games achievements not loading
**Problem:** Clicking game pills in My Games showed error: "Missing platform_id or platform_game_id for V2 schema"

**Root Cause:** The `get_user_grouped_games()` SQL function was returning JSONB without the V2 composite key fields (`platform_id`, `platform_game_id`)

**Fix:** 
- Migration: `20260122000001_fix_get_user_grouped_games_include_ids.sql`
- Added `platform_id` and `platform_game_id` to the JSONB response in the SQL function

---

### Issue #7: Flex Room not saving state
**Problem:** Changes to Flex Room would show success message but not persist after page refresh

**Root Cause:** Provider was invalidated immediately after save, triggering a refetch before the database transaction completed. This caused the UI to load stale data from cache.

**Fix:**
- File: `lib/ui/screens/flex_room_screen.dart` (lines 131-155)
- Removed `ref.invalidate(flexRoomDataProvider(userId))` call after successful save
- Let the cached `_savedData` hold changes until natural refetch on next screen visit

**Additional Fix:**
- File: `lib/data/repositories/flex_room_repository.dart`
- Updated `updateFlexRoomData` to set both `user_id` (deprecated but still primary key) and `profile_id` (new column)
- Added `onConflict: 'user_id'` to upsert for proper conflict resolution

---

### Issue #8: Xbox Leaderboard impossible Gamerscores
**Problem:** Xbox leaderboard showing values like 50,000G when realistic max is ~5,000G

**Root Cause:** The `xbox_leaderboard_cache` view was joining `user_achievements` with `user_progress`, causing `current_score` to be summed once per achievement instead of once per game. For example, a game worth 1,000G with 10 achievements earned would incorrectly show as 10,000G.

**Fix:**
- Migration: `20260122000002_fix_xbox_leaderboard_gamerscore_calculation.sql`
- Rewrote view using CTEs:
  - `xbox_user_stats` CTE: Counts achievements per user
  - `xbox_gamerscore` CTE: Sums per-game scores from `user_progress` (one row per game)
  - Final SELECT joins them together
- This ensures each game's total score is counted exactly once

---

### Issue #9: "Find Partner" trophy_help_requests null constraint
**Problem:** Creating a trophy help request failed with error: "Null value in column 'user_id' of relation 'trophy_help_requests' violates not-null constraint"

**Root Cause:** Table has both `user_id` (deprecated, NOT NULL, primary key) and `profile_id` (new column). Code was only setting `profile_id`.

**Fix:**
- File: `lib/services/trophy_help_service.dart`
- Updated `trophy_help_requests` insert to set both `user_id` and `profile_id` to the same value
- Updated `trophy_help_responses` insert to set both `helper_user_id` and `helper_profile_id`

---

### Issue #10: Comments and Tips achievement_comments null constraint
**Problem:** Posting a comment failed with error: "platform_id of relation 'achievement_comments' violates not-null constraint"

**Root Cause:** The `achievement_comments` table requires V2 composite keys (`platform_id`, `platform_game_id`, `platform_achievement_id`) but the code wasn't passing them.

**Fix:**
- File: `lib/services/achievement_comment_service.dart`
  - Updated `postComment()` method to accept composite key parameters
  - Updated insert to include `platform_id`, `platform_game_id`, `platform_achievement_id`
  
- File: `lib/ui/screens/achievement_comments_screen.dart`
  - Updated `AchievementCommentsScreen` constructor to accept composite keys
  - Updated `_CommentInput` widget to accept and pass composite keys
  
- File: `lib/ui/navigation/app_router.dart`
  - Updated route to parse composite keys from query parameters
  
- File: `lib/ui/screens/game_achievements_screen.dart`
  - Updated navigation to pass composite keys in query string
  - Added null checks to prevent crashes when V2 keys are missing
  - Updated achievement merge to include `platform_achievement_id` in the data structure

---

## Pattern: V2 Schema Migration
Many of these fixes follow a common pattern related to the V2 schema migration:

**The Problem:** Tables have both deprecated V1 fields and new V2 composite key fields. V1 fields often have NOT NULL constraints but are marked as deprecated.

**The Solution:**
1. Set BOTH the deprecated field AND the new field to the same value
2. When using composite keys, ensure all three parts are present (`platform_id`, `platform_game_id`, `platform_achievement_id`)
3. Add null checks before navigation/operations that require composite keys

**Affected Tables:**
- `flex_room_data`: `user_id` (deprecated) + `profile_id` (new)
- `trophy_help_requests`: `user_id` (deprecated) + `profile_id` (new)
- `trophy_help_responses`: `helper_user_id` (deprecated) + `helper_profile_id` (new)
- `achievement_comments`: Requires V2 composite keys (`platform_id`, `platform_game_id`, `platform_achievement_id`)

**Future Migration Note:** Eventually these deprecated columns should be removed via migration, but for now we maintain backward compatibility by setting both.

## StatusXP showing 0 in my games ##
1. In My Games - StatusXP is showing 0 for all games. (Fixed)

## UX Improvements ## (Complete)
2. On "My games" screen I would like the for it to be like this
  A. Playstation Games - Show the trophy breakdown, instead of just Playstation 28/28 100%  Actually show the trophy counts, like Platinum 1 | Gold 3 | Silver 4 | Bronze 20
  B. XBOX - SHow the Achivement score | total achivement score  =  Like this:  XBOX 10/30 30% Ahivement Points 300/1000
  C. STeam - Show achivements by achivement count  = 10/30 

  ## Enchanced Co-op helper function ## (Complete)
  1. Find Co-op Partners:
  When a Co-op request is created, it goes to the request board:  In the Find Help section you can click "Offer Help" and then "Send Offer"
    A.  When someone "Sends OFfer" it shows the user who sent the offer as "Helper USERID - Which it should be the username of the user.
    B.  When they click "Accept Offer" the process dies.  How are they supposed to continue the help offer?

## Status Poster Enhancements ## (Complete)
3. Status Poster - Load time is extremely long, should be instant
  A.  Also - right now we have RANK #2 but that is just playstation, We need to add the rank under the StatusXP pill for your rank in statusxp, move that playstation rank right under the psn pill, and do the same for XBOX and Steam leaderboards, the top 15% can remain right above the "Beat My SCore" message

## Pick Background Optimization ## (Complete)
4. When I select the "Change Background" it shows the Choose Background screen, but I can't see the pictures at the bottom to scroll, that whole screen should scroll so they can choose a picture, the subscreen

## Auto Restart Sync on Interruption ##
  - ✅ Sync restart function implemented (Jan 22, 2026) - will auto-resume interrupted syncs on app startup

 1. ✅ **Sync restart function** (Jan 22, 2026) - Implemented SyncResumeService that automatically detects and resumes interrupted syncs on app startup. Uses 5-minute timestamp threshold to distinguish truly interrupted syncs from active ones. Handles 409 conflicts by resetting sync status with helpful error message. File: lib/services/sync_resume_service.dart
2. ✅ **My Games Last Trophy sorting** (Jan 22, 2026) - Fixed get_user_grouped_games function to include last_played_at and last_trophy_earned_at in platforms JSON. Migration: 20260122000006_fix_last_trophy_sorting.sql
 
 1. ✅ Status Poster optimization and ranks (Jan 22, 2026) - Parallel loading, accurate rank display, centered rank badges
2. ✅ Choose Background scrolling (Jan 22, 2026) - Dynamic GridView height calculation for full scrolling
3. ✅ Sync restart function (Jan 22, 2026) - SyncResumeService with timestamp-based detection and 409 conflict handling
4. ✅ My Games Last Trophy sorting (Jan 22, 2026) - Fixed get_user_grouped_games function. Migration: 20260122000006_fix_last_trophy_sorting.sql
5. ✅ Updates section in settings (Jan 22, 2026) - Created app_updates table and UpdatesScreen. Migration: 20260122000007_create_app_updates_table.sql

