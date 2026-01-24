# iOS DEPLOYMENT FIX - Invalid API Error

## Problem
Apple users getting "Invalid API" error when trying to sign in with email/password or Apple Sign-In, even though the same credentials work on web.

## Root Cause
When building iOS apps through Xcode, the `--dart-define` flags that inject Supabase credentials were not being passed to the build. This caused the app to either:
1. Use empty/undefined Supabase URL and keys, OR
2. Fall back to defaults that might be misconfigured

## Solution Implemented

### 1. Created `ios/Flutter/DartDefines.xcconfig`
This file now contains the Supabase URL and anon key in the format Xcode expects:
```
DART_DEFINES=SUPABASE_URL%3Dhttps%3A%2F%2Fksriqcmumjkemtfjuedm.supabase.co,SUPABASE_ANON_KEY%3D[key]
```

**Note:** The values are URL-encoded (%3A = `:`, %2F = `/`)

### 2. Updated iOS Build Configuration Files
Modified both:
- `ios/Flutter/Debug.xcconfig` 
- `ios/Flutter/Release.xcconfig`

To include: `#include "DartDefines.xcconfig"`

This ensures Xcode passes the Supabase credentials to the Flutter build process.

## How to Deploy the Fix

### Option 1: Build via Command Line (Recommended)
```bash
cd d:\Dev\statusxp

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for iOS device (creates .ipa for TestFlight/App Store)
flutter build ios --release

# Or run on simulator for testing
flutter run -d "iPhone 15"
```

### Option 2: Build via Xcode
1. Open Xcode: `open ios/Runner.xcworkspace` (NOT .xcodeproj!)
2. Clean build folder: Product → Clean Build Folder (⇧⌘K)
3. Verify DartDefines.xcconfig is included:
   - Select Runner in project navigator
   - Select Runner target
   - Go to Build Settings
   - Search for "DART_DEFINES"
   - Should show the Supabase URL
4. Build and run: Product → Run (⌘R)

## Testing the Fix

### 1. Test Email/Password Sign-In
1. Launch the app on iOS device/simulator
2. Tap "Continue with Login"
3. Enter valid email and password
4. Should successfully sign in (no "Invalid API" error)

### 2. Test Apple Sign-In
1. Launch the app
2. Tap "Continue with Apple"
3. Complete Apple authentication
4. Should successfully sign in/create account

### 3. Verify Supabase Connection
Add this temporary debug code to `lib/main.dart` after Supabase initialization:
```dart
print('🔍 Supabase URL: ${Supabase.instance.client.supabaseUrl}');
print('🔍 Supabase Key: ${Supabase.instance.client.supabaseKey.substring(0, 20)}...');
```

Expected output:
```
🔍 Supabase URL: https://ksriqcmumjkemtfjuedm.supabase.co
🔍 Supabase Key: eyJhbGciOiJIUzI1NiI...
```

If you see empty strings or wrong values, the dart-defines are not being applied.

## Why This Happened

The web build works because `build.sh` explicitly passes `--dart-define` flags:
```bash
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

But iOS builds through Xcode don't automatically get these flags. The `DartDefines.xcconfig` file bridges this gap.

## For Your User to Fix Immediately

**Tell your user to:**
1. Delete the StatusXP app from their iPhone
2. Restart their iPhone
3. Install the latest version from TestFlight or App Store (after you deploy the fix)
4. Try signing in again

If they're testing via TestFlight:
- Wait for the new build (with this fix) to be uploaded
- Install the update
- Test sign-in

## Future Deployments

**ALWAYS build iOS apps using one of these methods:**

### For TestFlight/App Store:
```bash
flutter clean
flutter pub get
flutter build ios --release
# Then archive in Xcode and upload to App Store Connect
```

### For Local Testing:
```bash
flutter run -d "Your Device Name"
```

**NEVER** build directly in Xcode without first running `flutter build ios` or ensuring DartDefines.xcconfig is properly configured.

## Verification Checklist

Before deploying to TestFlight/App Store:
- [ ] `ios/Flutter/DartDefines.xcconfig` exists and contains correct Supabase values
- [ ] Both `Debug.xcconfig` and `Release.xcconfig` include `DartDefines.xcconfig`
- [ ] Run `flutter clean` before building
- [ ] Test email/password sign-in on iOS simulator
- [ ] Test Apple Sign-In on iOS simulator
- [ ] Test on physical iPhone device
- [ ] Verify no "Invalid API" errors in logs
- [ ] Confirm user can sign up and sign in successfully

## Additional Notes

### About the Fallback in supabase_config.dart
The file `lib/config/supabase_config.dart` has hardcoded fallback values:
```dart
return 'https://ksriqcmumjkemtfjuedm.supabase.co';
```

These SHOULD work as a fallback, but it's better to have explicit dart-defines passed through the build system to avoid any edge cases or caching issues.

### About Apple Sign-In Configuration
If Apple Sign-In still has issues after this fix, also verify:
1. `ios/Runner/Info.plist` has the correct URL schemes
2. Apple Sign-In capability is enabled in Xcode (Signing & Capabilities tab)
3. Bundle identifier matches the one registered in Apple Developer Portal

### About Android
Android builds are not affected by this issue because they use a different build process and the `--dart-define` flags are passed correctly through Gradle.
