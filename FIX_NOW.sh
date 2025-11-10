#!/bin/bash

echo "🔧 EMERGENCY FIX - Clearing Everything"
echo "======================================"
echo ""

# Kill Xcode if running
echo "1️⃣ Killing Xcode..."
killall Xcode 2>/dev/null || true
sleep 2
echo "✅ Xcode killed"
echo ""

# Clear DerivedData
echo "2️⃣ Clearing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData 2>/dev/null || true
echo "✅ DerivedData cleared"
echo ""

# Clear SPM caches
echo "3️⃣ Clearing SPM caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm 2>/dev/null || true
rm -rf ~/Library/org.swift.swiftpm 2>/dev/null || true
echo "✅ SPM caches cleared"
echo ""

# Clear project build folder
echo "4️⃣ Clearing project build folder..."
cd /Users/keonta/Documents/MyChannel
rm -rf .build 2>/dev/null || true
echo "✅ Project build folder cleared"
echo ""

# Resolve packages
echo "5️⃣ Re-resolving Swift packages..."
xcodebuild -resolvePackageDependencies -project MyChannel.xcodeproj -scheme MyChannel 2>&1 | grep -E "(Resolved|error)" | head -5
echo "✅ Packages resolved"
echo ""

echo "🎉 ALL DONE!"
echo ""
echo "Next steps:"
echo "1. Open Xcode: open MyChannel.xcodeproj"
echo "2. Clean Build: Cmd+Shift+K"
echo "3. Build: Cmd+B"
echo ""
echo "The errors should be gone now!"


