# Firebase Analytics Setup Guide

## Current Status ✅
- Firebase Analytics dependencies added to `pubspec.yaml`
- Android build configuration updated for Google Services
- Analytics service created (`lib/services/analytics_service.dart`)
- Automatic screen tracking enabled via router observer
- Firebase initialization added to `main.dart`

## Next Steps

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "**Add project**"
3. Name it "**StatusXP**"
4. Enable **Google Analytics** when prompted
5. Select or create an Analytics account
6. Complete the setup

### 2. Add Android App
1. In your Firebase project dashboard, click the **Android icon** (⚙️)
2. Enter package name: `com.statusxp.statusxp`
3. (Optional) App nickname: "StatusXP"
4. (Optional) SHA-1: Use `Get-Content android/app/debug.keystore | openssl sha1` if needed
5. Click "**Register app**"

### 3. Download Config File
1. Download the `google-services.json` file
2. Place it in: `android/app/google-services.json`
3. **IMPORTANT**: Add it to `.gitignore` if not already there

### 4. (Optional) Add iOS App
If you want iOS analytics too:
1. Click the **Apple icon** in Firebase Console
2. Bundle ID: Check `ios/Runner.xcodeproj/project.pbxproj` for your bundle ID
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`
5. Open Xcode and add it to the Runner target

## What's Tracked Automatically

### Screen Views
Every screen navigation is automatically logged:
- Dashboard
- Games List
- Game Details
- Leaderboards
- Flex Room
- Settings
- etc.

### Custom Events Available
Use these methods in your code:

```dart
import 'package:statusxp/services/analytics_service.dart';

final analytics = AnalyticsService();

// Track syncs
await analytics.logSync(platform: 'psn', isAutoSync: false);

// Track game views
await analytics.logViewGame(gameName: 'Game Title', platform: 'psn');

// Track AI guide unlocks
await analytics.logUnlockGuide(achievementName: 'Trophy Name', gameName: 'Game');

// Track shares
await analytics.logSharePoster();

// Track Flex Room edits
await analytics.logEditFlexRoom(section: 'superlatives');

// Track leaderboard views
await analytics.logViewLeaderboard(leaderboardType: 'statusxp');

// Track search
await analytics.logSearchGames(query: 'dark souls', platform: 'psn');

// Track account linking
await analytics.logLinkAccount(platform: 'xbox');

// Custom events
await analytics.logCustomEvent(
  eventName: 'feature_used',
  parameters: {'feature': 'premium_filter'},
);
```

## Where to Add Event Tracking

### Sync Buttons (PSN/Xbox/Steam)
In `psn_sync_screen.dart`, `xbox_sync_screen.dart`:
```dart
await analytics.logSync(platform: 'psn', isAutoSync: false);
// ... start sync
```

### Share Button (Status Poster)
In `status_poster_screen.dart`:
```dart
await analytics.logSharePoster();
// ... share logic
```

### Game Clicks
In game list/browser screens:
```dart
await analytics.logViewGame(
  gameName: game.name,
  platform: game.platform,
);
```

### Leaderboard Tabs
In `leaderboard_screen.dart`:
```dart
await analytics.logViewLeaderboard(leaderboardType: selectedTab);
```

## Viewing Analytics Data

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your "StatusXP" project
3. Click **Analytics** in left sidebar
4. View:
   - **Dashboard**: Overview of active users, sessions, etc.
   - **Events**: See all tracked events
   - **Conversions**: Mark important events as conversions
   - **Audiences**: Create user segments
   - **Realtime**: See live user activity

## Testing

### Debug View (Android)
Enable debug mode to see events in real-time:
```bash
adb shell setprop debug.firebase.analytics.app com.statusxp.statusxp
```

Disable debug mode:
```bash
adb shell setprop debug.firebase.analytics.app .none.
```

Then view in Firebase Console > Analytics > DebugView

### Verify Events
Events may take 24-48 hours to appear in Firebase Console reports.
Use DebugView for real-time testing.

## Important Notes

- ⚠️ Analytics is currently **disabled on web** (needs separate web configuration)
- 🔒 `google-services.json` should be in `.gitignore`
- 📊 Events are batched and sent periodically (not instant)
- 🐛 Debug mode shows events in real-time for testing
- 🎯 Screen tracking is automatic via router observer

## Next Build

After adding `google-services.json`:
```bash
flutter pub get
flutter clean
flutter build appbundle --release
```

## Questions?
- [Firebase Analytics Docs](https://firebase.google.com/docs/analytics)
- [FlutterFire Docs](https://firebase.flutter.dev/docs/analytics/overview)
