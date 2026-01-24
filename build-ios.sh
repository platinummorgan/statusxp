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

echo ""
echo "✅ Build complete!"
echo ""
echo "📱 Next steps:"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Select 'Any iOS Device' from device dropdown"
echo "3. Go to Product → Archive"
echo "4. Distribute to App Store Connect"
