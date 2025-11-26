#!/bin/bash

echo "🔥 REBUILDING APP TO DISABLE NATIVE iOS PiP"
echo ""
echo "This will:"
echo "1. Clean build folder"
echo "2. Remove DerivedData"
echo "3. Rebuild app with PiP disabled"
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

# Clean build
echo "🧹 Cleaning build folder..."
xcodebuild clean -project MyChannel.xcodeproj -scheme MyChannel

# Remove DerivedData for this project
echo "🗑️  Removing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-*

# Rebuild
echo "🔨 Rebuilding app..."
xcodebuild -project MyChannel.xcodeproj -scheme MyChannel -sdk iphonesimulator -configuration Debug build

echo ""
echo "✅ REBUILD COMPLETE!"
echo ""
echo "Now run the app in Xcode and native iOS PiP will be DISABLED."
echo "Only the custom YouTube-style mini-player will appear!"







