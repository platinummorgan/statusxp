# Audit Queries - Fixed and Ready to Run

All SQL files have been updated to use the correct table names (`user_achievements` instead of `user_progress_v2`).

## Run These Queries In Order:

### 1. audit_platform_duplicates.sql
**Purpose:** Find all games incorrectly duplicated across platform generations
- PS4/PS5 duplicates
- Xbox 360/One/Series X duplicates
- Summary counts of affected games

### 2. check_duplicate_credit_issue.sql
**Purpose:** Check if users are receiving duplicate credit for backwards compatible games
- Verify PROTOTYPE game status
- Find users with same game on multiple Xbox platforms
- Identify duplicate credit scenarios

### 3. distinguish_stacking_vs_bug.sql
**Purpose:** Distinguish legitimate stacking from backwards compatibility bugs
- Uses timestamp analysis (achievements earned months/years apart = legitimate)
- Identifies same-day syncs that indicate bugs
- Shows which games have user data vs which are just empty table entries

## What to Look For:

### Legitimate Stacking (KEEP):
- User has same game on multiple platforms
- Achievement earned dates are months/years apart
- Indicates user genuinely replayed the game

### Backwards Compatibility Bug (FIX):
- User has same game on multiple platforms
- Achievement earned dates are same day or within hours
- Game exists in `games` table on multiple platforms but achievements only stored on one
- Indicates sync service created duplicate entries

## Next Steps After Running:
1. Review results to determine scope
2. Identify which games need platform consolidation
3. Create bulk fix script based on findings
4. Update sync services to prevent future duplicates
