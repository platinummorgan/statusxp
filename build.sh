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
flutter build web --release --no-tree-shake-icons

echo "Build completed successfully!"
