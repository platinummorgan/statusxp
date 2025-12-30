# Release Notes - Version 1.0.0+28

## Bug Fixes

### Dashboard
- Fixed StatusXP calculation on dashboard to match leaderboard values
- Dashboard now reads from the same leaderboard cache as the leaderboard screen for consistency

### Premium AI Achievement Guides
- Fixed "source column does not exist" error when generating AI guides
- Fixed duplicate key error when using AI guides multiple times per day
- Premium users can now generate unlimited AI guides without errors

### Network Connectivity
- Improved error handling for intermittent network connectivity issues
- Prevented authentication errors from showing during temporary network drops

## Technical Improvements
- Applied database migrations 108 and 109 for AI credit system
- Updated dashboard repository to use leaderboard_cache materialized view
- Added ON CONFLICT handling to AI credit consumption function
