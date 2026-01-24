# Quick Fix for iOS "Invalid API" Error

## Immediate Solution

The issue is that iOS builds need to be done through Flutter CLI, not directly through Xcode, to ensure Supabase credentials are properly injected.

### Step 1: Rebuild the iOS App Properly

Open PowerShell/Terminal and run:

```bash
cd d:\Dev\statusxp

# Clean all previous builds
flutter clean

# Get dependencies (this regenerates Generated.xcconfig)
flutter pub get

# Build for iOS (this will inject dart-defines properly)
flutter build ios --release --dart-define=SUPABASE_URL="https://ksriqcmumjkemtfjuedm.supabase.co" --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"
```

### Step 2: Archive in Xcode

After the build completes:

1. Open Xcode: `open ios/Runner.xcworkspace`
2. Select "Any iOS Device" or "Generic iOS Device" from device dropdown
3. Go to Product → Archive
4. Upload to TestFlight/App Store Connect

### Step 3: Tell Your User

Once the new build is uploaded to TestFlight:
1. Delete StatusXP app from iPhone
2. Install the new build from TestFlight
3. Try signing in with email/password
4. Try signing up with Apple

## Why This Happened

The hardcoded fallbacks in `lib/config/supabase_config.dart` SHOULD have worked, but they might not be getting executed properly on iOS for some reason (possibly a caching issue or the String.fromEnvironment check is failing).

By explicitly passing `--dart-define` flags during the iOS build, we ensure the correct values are baked into the compiled app.

## For Future Builds

**ALWAYS use this command for iOS release builds:**

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL="https://ksriqcmumjkemtfjuedm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"
```

## Testing Locally Before Upload

To test on a physical device or simulator:

```bash
# For simulator
flutter run -d "iPhone 15 Pro" \
  --dart-define=SUPABASE_URL="https://ksriqcmumjkemtfjuedm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"

# For physical device (connect via USB)
flutter run -d "Your iPhone Name" \
  --dart-define=SUPABASE_URL="https://ksriqcmumjkemtfjuedm.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"
```

Test:
1. Email/password sign in
2. Apple Sign-In
3. Sign up flow

All should work without "Invalid API" errors.

## Alternative: Create a Build Script

Save this as `build-ios.sh` in the project root:

```bash
#!/bin/bash
set -e

SUPABASE_URL="https://ksriqcmumjkemtfjuedm.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"

echo "🧹 Cleaning previous builds..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building iOS release..."
flutter build ios --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "✅ Build complete! Now open Xcode and archive:"
echo "   open ios/Runner.xcworkspace"
```

Then just run: `./build-ios.sh`
