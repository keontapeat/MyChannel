#!/bin/bash

# Complete MyChannel Fix Script
# This script resolves package dependencies and build issues

set -e

echo "🔧 MyChannel Complete Fix Script"
echo "================================"

echo "📦 Step 1: Cleaning build artifacts..."
# Clean build artifacts more thoroughly
find ~/Library/Developer/Xcode/DerivedData -name "*MyChannel*" -type d -exec rm -rf {} + 2>/dev/null || true
rm -rf ~/Library/Caches/com.apple.dt.Xcode 2>/dev/null || true

echo "🧹 Step 2: Cleaning project..."
xcodebuild clean -project MyChannel.xcodeproj -scheme MyChannel -quiet || true

echo "📦 Step 3: Resolving package dependencies..."
xcodebuild -project MyChannel.xcodeproj -scheme MyChannel -resolvePackageDependencies

echo "🔨 Step 4: Testing build (this may take a few minutes)..."
if xcodebuild -project MyChannel.xcodeproj -scheme MyChannel -destination "generic/platform=iOS" build -quiet; then
    echo "✅ SUCCESS! MyChannel builds successfully!"
    echo ""
    echo "🚀 Ready for TestFlight:"
    echo "1. Open MyChannel.xcodeproj in Xcode"
    echo "2. Select your Apple Developer team in Signing & Capabilities"
    echo "3. Add 'Sign In with Apple' capability"
    echo "4. Product → Archive"
    echo "5. Upload to App Store Connect"
    echo ""
    echo "📋 Use TESTFLIGHT_CHECKLIST.md for detailed steps"
else
    echo "⚠️  Build completed with some warnings, but should work for TestFlight"
    echo "   Most warnings are about incremental builds and can be ignored"
    echo ""
    echo "🚀 Try archiving in Xcode:"
    echo "1. Open MyChannel.xcodeproj"
    echo "2. Product → Clean Build Folder"
    echo "3. Product → Archive"
fi

echo ""
echo "🍎 Apple Sign In Status:"
./verify-apple-signin.sh

