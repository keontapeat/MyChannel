#!/bin/bash

echo "🔥 Firebase Package Dependency Fixer"
echo "===================================="
echo ""

PROJECT_DIR="/Users/keonta/Documents/MyChannel"
cd "$PROJECT_DIR"

echo "Step 1: Clearing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-* 2>/dev/null
echo "✅ DerivedData cleared"
echo ""

echo "Step 2: Clearing SPM caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm 2>/dev/null
rm -rf ~/Library/org.swift.swiftpm 2>/dev/null
echo "✅ SPM caches cleared"
echo ""

echo "Step 3: Resolving package dependencies..."
xcodebuild -resolvePackageDependencies -project MyChannel.xcodeproj -scheme MyChannel 2>&1 | \
    grep -E "(Fetching|Resolved|error)" | head -20
echo ""
echo "✅ Package resolution complete"
echo ""

echo "🎉 Firebase packages should now be fixed!"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Clean Build (Cmd+Shift+K)"
echo "3. Build (Cmd+B)"
echo ""
echo "If you still have issues, try:"
echo "  - File > Packages > Reset Package Caches (in Xcode)"
echo "  - Restart Xcode"
echo "  - Run this script again"


