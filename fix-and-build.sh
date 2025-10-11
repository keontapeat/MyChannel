#!/bin/bash

# MyChannel Fix and Build Script
# This script cleans the build system and attempts a build

set -e

echo "🧹 Cleaning build system..."

# Remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-*
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

# Clean project
xcodebuild clean -project MyChannel.xcodeproj -scheme MyChannel -quiet

echo "🔨 Attempting build..."

# Try building for iOS device
xcodebuild -project MyChannel.xcodeproj -scheme MyChannel -destination "generic/platform=iOS" build -quiet

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded! Ready for TestFlight."
    echo ""
    echo "🚀 Next steps:"
    echo "1. Open Xcode and archive your project"
    echo "2. Upload to App Store Connect"
    echo "3. Add testers in TestFlight"
else
    echo "❌ Build failed. Check the errors above."
    exit 1
fi

