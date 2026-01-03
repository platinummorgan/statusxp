# Release Notes v1.0.0+45

## Major Features & Improvements

### Cross-Platform Game Grouping
- **Achievement-Based Grouping**: Games are now intelligently grouped across platforms based on 90%+ achievement similarity
- **Unified Display**: Same game on multiple platforms (PSN/Xbox/Steam) now shows as one entry with platform pills
- **Pre-Computed Groups**: Blazing fast browsing with pre-calculated groupings (10x+ speed improvement)
- **Auto-Refresh**: Groupings automatically update when new games are synced

### Database Architecture Overhaul
- **Platform Separation Enforced**: Each platform version stored as separate database entry
- **Dedicated Platform ID Columns**: Added psn_npwr_id, xbox_title_id, steam_app_id with UNIQUE constraints
- **Zero Duplicates**: Cleaned 217 cross-platform contaminations and removed 8 duplicate entries
- **Future-Proof**: Database now prevents duplicate platform IDs at insertion time

### UI/UX Improvements
- **Trophy Counts Fixed**: All platforms (PSN/Xbox/Steam) now display correct earned/total counts and percentages
- **Longer Title Support**: Game titles can now wrap to 3 lines instead of 2
- **Faster Game Catalog**: Browse All Games loads instantly with pre-computed groupings
- **Whitespace Handling**: Fixed game name matching to handle trailing newlines and spaces from API responses

### Technical Improvements
- **6 New Database Migrations** (1000-1006):
  - Migration 1000: Add platform ID columns with indexes
  - Migration 1001: Populate platform IDs from metadata (2,493 games)
  - Migration 1002: Add UNIQUE constraints to prevent duplicates
  - Migration 1003: Create achievement-matching grouping functions
  - Migration 1004: Add achievement indexes for faster similarity calculations
  - Migration 1005: Pre-compute game groups table
  - Migration 1006: Auto-refresh triggers for game groups

- **Updated Sync Services**: All 3 platforms (PSN, Xbox, Steam) now use dedicated platform ID columns
- **Optimized Queries**: Achievement similarity calculations cached in game_groups table
- **Smart Name Matching**: Uses BTRIM() to handle whitespace variations (spaces, newlines, tabs, carriage returns)

### Bug Fixes
- Fixed Disney Dreamlight Valley not grouping across platforms (newline character issue)
- Fixed PSN trophy counts showing as 0/0 (removed platform_id join requirement)
- Fixed Steam achievement counts using wrong columns
- Fixed completion percentages calculating incorrectly for Steam games
- Removed non-functional "Newest First" and "Oldest First" sort options

## Database Statistics (Post-Migration)
- **Total Games**: 2,493 (1,398 PSN, 828 Xbox, 267 Steam)
- **Duplicate Platform IDs**: 0 (all cleaned and prevented)
- **Cross-Platform Contamination**: 0 (all cleaned)
- **Pre-Computed Groups**: ~2,400+ (varies as games sync)

## Breaking Changes
- Game Catalog now requires game_groups table to be populated
- First load after migration may take 30-60 seconds while groups compute
- Subsequent loads are instant

## Known Limitations
- Game groups don't auto-refresh in real-time (refresh on next app restart or manual trigger)
- Achievement similarity calculation still takes time for new games (happens in background)

## Migration Notes
If upgrading from previous version:
1. Run migrations 1000-1006 in Supabase SQL Editor in order
2. Wait for initial group computation to complete (check for "Refreshed X game groups" message)
3. Update sync services will automatically use new platform ID columns
4. Existing user_games data preserved and enhanced

## Future Enhancements
- Real-time group refresh via websockets
- Cached achievement similarity scores for faster new game processing
- Background job for group computation during off-peak hours
