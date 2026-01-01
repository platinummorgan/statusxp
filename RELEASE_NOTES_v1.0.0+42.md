# Release Notes - Version 1.0.0+42

**Release Date**: January 1, 2026

## 🐛 Bug Fixes

### UI Improvements
- **Fixed Xbox leaderboard overflow** - Resolved rendering overflow (2.7-4.9 pixels) in leaderboard cards when displaying games count alongside high scores. The games count text now flexes and ellipsizes properly when space is constrained.

### Steam Privacy Warnings
- **Added prominent Steam privacy alerts** - Users now see clear warnings about Steam profile privacy requirements before and during sync:
  - Orange warning card in Steam configuration screen
  - Highlighted privacy requirements at top of sync instructions
  - Explains that "Game details" must be set to Public in Steam Privacy Settings
- **Updated support documentation** - Added FAQ entry for "403 Forbidden" errors during Steam sync with step-by-step privacy settings fix

## 📝 Technical Details

### Fixed Issues
- **Issue**: RenderFlex overflow in leaderboard cards when subtitle + score exceeded available space (190px constraint)
- **Root Cause**: Fixed-width Text widgets in Row with spaceBetween alignment
- **Solution**: Wrapped subtitle Text in Flexible widget with TextOverflow.ellipsis
- **Issue**: Users experiencing 403 errors during Steam sync didn't understand privacy requirements
- **Root Cause**: Steam API blocks achievement data when profile privacy set to Friends Only or Private
- **Solution**: Added prominent warnings in UI and documentation explaining Public profile requirement

### Files Modified
- `lib/ui/screens/leaderboard_screen.dart` - Fixed overflow in games count display
- `lib/ui/screens/steam/steam_configure_screen.dart` - Added privacy warning card
- `lib/ui/screens/steam/steam_sync_screen.dart` - Enhanced sync instructions with privacy requirements
- `SUPPORT.md` - Added 403 Forbidden error FAQ entry
- `pubspec.yaml` - Version bump to 1.0.0+42

## 🔍 Impact
- **Leaderboards**: Cards now render cleanly without overflow warnings on all screen sizes
- **Steam Sync**: Users are now properly informed about privacy requirements before encountering sync errors
- **User Experience**: Fewer support requests for "sync not working" issues due to clearer privacy guidance

---

## For Testers

### Test Scenarios

1. **Leaderboard Overflow Fix**
   - Navigate to Xbox Gamerscore or Steam Achievements leaderboard
   - Verify no yellow/black overflow stripes appear on leaderboard cards
   - Check that games count text ellipsizes gracefully when scores are large

2. **Steam Privacy Warnings**
   - Navigate to Settings → Platform Connections → Configure Steam
   - Verify orange privacy warning card appears before instructions
   - Navigate to Steam Sync screen
   - Verify privacy requirements are highlighted at top of instructions
   - Test with profile set to Private (should see 403 errors with clear understanding of cause)
   - Test with profile set to Public (should sync successfully)

### Known Issues
- None specific to this release

---

**Previous Version**: 1.0.0+41  
**Current Version**: 1.0.0+42
