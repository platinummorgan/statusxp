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
echo "SUPABASE_URL from Vercel: $SUPABASE_URL"
echo "SUPABASE_ANON_KEY from Vercel: ${SUPABASE_ANON_KEY:0:20}..."

# Create .env file from Vercel environment variables
cat > .env << EOF
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
EOF

echo "Created .env file with Vercel environment variables"
cat .env

flutter build web --release --no-tree-shake-icons

echo "Build completed successfully!"
