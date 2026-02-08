#!/bin/bash
set -e

echo "===================="
echo "Current directory: $(pwd)"
echo "===================="
echo "Listing all files (including hidden):"
ls -lha
echo "===================="
echo "Checking for pubspec.yaml:"
find . -name "pubspec.yaml" -type f 2>/dev/null || echo "No pubspec.yaml found anywhere"
echo "===================="

# Check if pubspec.yaml exists
if [ -f "pubspec.yaml" ]; then
    echo "✓ Found pubspec.yaml in root"
elif [ -f "./pubspec.yaml" ]; then
    echo "✓ Found pubspec.yaml with explicit path"
else
    echo "✗ ERROR: pubspec.yaml not found!"
    echo "Full directory tree:"
    find . -maxdepth 2 -type f 2>/dev/null | head -20
    exit 1
fi

echo "Starting Flutter Web build..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Installing Flutter..."
    
    # Clone Flutter SDK
    git clone https://github.com/flutter/flutter.git -b stable --depth 1 /tmp/flutter
    export PATH="$PATH:/tmp/flutter/bin"
    
    # Configure Flutter
    flutter config --no-analytics
    flutter --version
fi

# Build the web app
echo "Building Flutter web app..."

# Clean previous build artifacts
echo "Cleaning previous builds..."
flutter clean
rm -rf build/web

# Use compile-time dart-define for configuration
SUPABASE_URL="https://ksriqcmumjkemtfjuedm.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"

echo "Using SUPABASE_URL: $SUPABASE_URL"

# Get dependencies fresh
flutter pub get

flutter build web --release --no-tree-shake-icons \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# Copy static files to build output
echo "Copying static files..."
if [ -f "web/robots.txt" ]; then
  cp web/robots.txt build/web/robots.txt
  echo "✓ Copied robots.txt"
else
  echo "✗ robots.txt not found in web/"
fi

if [ -f "web/sitemap.xml" ]; then
  cp web/sitemap.xml build/web/sitemap.xml
  echo "✓ Copied sitemap.xml"
else
  echo "✗ sitemap.xml not found in web/"
fi

echo "Verifying files in build/web..."
ls -la build/web/robots.txt build/web/sitemap.xml 2>&1

echo "Build completed successfully!"
