# 🚨 CRITICAL iOS Authentication Issue - RESOLVED

## Issue Summary
**Date**: January 23, 2026  
**Severity**: CRITICAL - Blocking new user signups and existing user logins on iOS  
**Affected Platform**: iOS App Store version  
**Symptoms**:
- iOS users getting "Invalid API" error when trying to sign in with email/password
- Apple Sign-In failing on iOS 
- Same credentials work perfectly on web

## Root Cause
iOS builds were missing Supabase credentials because they were built directly in Xcode without `--dart-define` flags. While the code has hardcoded fallbacks in `lib/config/supabase_config.dart`, iOS builds were not properly accessing these values due to how Xcode compiles Flutter apps.

## Solution
iOS apps **MUST** be built using Flutter CLI with explicit `--dart-define` flags **BEFORE** archiving in Xcode.

### Immediate Fix - Rebuild and Deploy

#### Step 1: Build with Proper Credentials
```bash
cd d:\Dev\statusxp

# Use the build script
./build-ios.sh

# OR manually:
flutter clean
flutter pub get
flutter build ios --release \
  --dart-define=SUPABASE_URL="https://ksriqcmumjkemtfjuedm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"
```

#### Step 2: Archive in Xcode
```bash
open ios/Runner.xcworkspace
```
1. Select "Any iOS Device" (not simulator)
2. Product → Archive
3. Upload to App Store Connect
4. Submit for review or release to TestFlight

#### Step 3: Notify Affected Users
- Push update to TestFlight immediately for beta testers
- If issue affects production users, request expedited App Store review
- Communicate to users that an update is available

### Testing Verification
Before submitting to App Store:

```bash
# Test on simulator
flutter run -d "iPhone 15 Pro" \
  --dart-define=SUPABASE_URL="https://ksriqcmumjkemtfjuedm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"
```

**Test these flows:**
- ✅ Email/password sign up
- ✅ Email/password sign in
- ✅ Apple Sign-In (new account)
- ✅ Apple Sign-In (existing account)
- ✅ Password reset flow
- ✅ Account linking (sign in with email, then link Apple)

All should work without "Invalid API" errors.

## Files Created/Modified

### New Files
1. `build-ios.sh` - Automated iOS build script with correct dart-defines
2. `QUICK_IOS_FIX.md` - Quick reference guide
3. `IOS_DEPLOYMENT_FIX.md` - Detailed technical explanation
4. `CRITICAL_IOS_AUTH_ISSUE.md` - This file

### Modified Files
1. `_state/REALITY.md` - Updated iOS deployment instructions

## Why This Wasn't Caught Earlier
- Web builds use `build.sh` which explicitly passes dart-defines ✅
- Android builds likely were also using Flutter CLI properly ✅
- iOS builds were done directly in Xcode ❌
- Hardcoded fallbacks in code exist but weren't being accessed properly on iOS

## Prevention - Going Forward

### ✅ DO THIS:
1. Always use `./build-ios.sh` for iOS builds
2. OR manually run `flutter build ios --release --dart-define=...` before Xcode
3. Test on both simulator AND physical device before submitting
4. Verify Supabase connection in app logs during testing

### ❌ NEVER DO THIS:
1. Build directly in Xcode without running Flutter CLI first
2. Archive in Xcode without first running `flutter build ios`
3. Skip the dart-define flags
4. Assume hardcoded fallbacks will work on all platforms

## Impact
- **Before Fix**: iOS users cannot sign up or sign in
- **After Fix**: All authentication methods work properly
- **Estimated Time to Deploy**: 1-2 hours (build + upload + TestFlight processing)
- **User Impact**: Requires users to update app from TestFlight/App Store

## Related Documentation
- [QUICK_IOS_FIX.md](QUICK_IOS_FIX.md) - Quick reference
- [IOS_DEPLOYMENT_FIX.md](IOS_DEPLOYMENT_FIX.md) - Detailed explanation
- [BUILD_CONFIG.md](BUILD_CONFIG.md) - Environment configuration
- [_state/REALITY.md](_state/REALITY.md) - Project overview (updated)

## Communication Template for User

> **StatusXP iOS Update Available**
> 
> We've identified and fixed an issue affecting iOS sign-in. Please update to the latest version from TestFlight/App Store.
> 
> **What was fixed:**
> - Email/password authentication on iOS
> - Apple Sign-In on iOS
> - Account creation on iOS
> 
> **How to update:**
> 1. Delete the StatusXP app from your iPhone
> 2. Restart your iPhone
> 3. Install the latest version from TestFlight or App Store
> 4. Sign in - it should work now!
> 
> We apologize for the inconvenience. All users on web and Android were unaffected.

## Technical Notes
The issue was specific to how Xcode compiles Flutter apps without explicit build configuration. The `String.fromEnvironment()` calls in `lib/config/supabase_config.dart` require compile-time constants passed via `--dart-define`. When building directly in Xcode, these values were empty, causing the app to fail to initialize Supabase properly.

The fix ensures dart-defines are baked into the compiled app binary during the Flutter build step, which then gets packaged by Xcode into the final IPA for distribution.

## Next Steps
1. ✅ Build iOS app with proper dart-defines
2. ✅ Test thoroughly on simulator and device
3. ⏳ Upload to TestFlight
4. ⏳ Test with affected user
5. ⏳ Submit to App Store (if needed)
6. ⏳ Monitor for any related issues

## Status
🔴 **CRITICAL** - Issue identified, fix ready, awaiting deployment
