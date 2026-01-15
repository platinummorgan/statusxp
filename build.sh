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

# Debug: Check all environment variables
echo "=== Environment Variables Check ==="
env | grep -i supabase || echo "No SUPABASE vars found"
echo "=================================="

# Use hardcoded values if env vars not available
SUPABASE_URL="${SUPABASE_URL:-https://ksriqcmumjkemtfjuedm.supabase.co}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MTQxODQsImV4cCI6MjA4MDI5MDE4NH0.svxzehEtMDUQjF-stp7GL_LmRKQOFu_6PxI0IgbLVoQ}"

echo "Using SUPABASE_URL: $SUPABASE_URL"
echo "Using SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."

# Create .env file
cat > .env << EOF
SUPABASE_URL=$SUPABASE_URL
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
EOF

echo "Created .env file:"
cat .env

flutter build web --release --no-tree-shake-icons

echo "Build completed successfully!"
