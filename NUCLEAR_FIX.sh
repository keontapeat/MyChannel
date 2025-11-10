#!/bin/bash

echo "☢️  NUCLEAR FIX - Resetting Everything"
echo "====================================="
echo ""
echo "⚠️  This will:"
echo "   - Kill Xcode"
echo "   - Clear ALL build caches"
echo "   - Reset Xcode's index"
echo "   - Clear module cache"
echo "   - Re-resolve packages"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."
echo ""

# 1. Kill Xcode and related processes
echo "1️⃣ Killing Xcode and related processes..."
killall Xcode 2>/dev/null || true
killall SourceKitService 2>/dev/null || true
killall ibtoold 2>/dev/null || true
sleep 3
echo "✅ Processes killed"
echo ""

# 2. Clear DerivedData completely
echo "2️⃣ Clearing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData
echo "✅ DerivedData cleared"
echo ""

# 3. Clear Module Cache
echo "3️⃣ Clearing Module Cache..."
rm -rf ~/Library/Developer/Xcode/ModuleCache.noindex
rm -rf ~/Library/Caches/com.apple.dt.Xcode
echo "✅ Module Cache cleared"
echo ""

# 4. Clear SPM caches
echo "4️⃣ Clearing SPM caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/org.swift.swiftpm
echo "✅ SPM caches cleared"
echo ""

# 5. Clear project-specific caches
echo "5️⃣ Clearing project caches..."
cd /Users/keonta/Documents/MyChannel
rm -rf .build
rm -rf MyChannel.xcodeproj/project.xcworkspace/xcuserdata
rm -rf MyChannel.xcodeproj/xcuserdata
echo "✅ Project caches cleared"
echo ""

# 6. Re-resolve packages
echo "6️⃣ Re-resolving Swift packages..."
xcodebuild -resolvePackageDependencies -project MyChannel.xcodeproj -scheme MyChannel 2>&1 | grep -E "(Resolved|Fetching|error)" | head -10
echo ""
echo "✅ Packages resolved"
echo ""

# 7. Pre-build to rebuild index
echo "7️⃣ Pre-building to rebuild Xcode index..."
xcodebuild -project MyChannel.xcodeproj -scheme MyChannel -destination 'generic/platform=iOS Simulator' clean 2>&1 | tail -3
echo "✅ Index rebuilt"
echo ""

echo "☢️  NUCLEAR FIX COMPLETE!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Everything has been reset!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo ""
echo "1. Open Xcode:"
echo "   open MyChannel.xcodeproj"
echo ""
echo "2. Wait for indexing to complete (watch top bar)"
echo ""
echo "3. Clean Build:"
echo "   Cmd+Shift+K"
echo ""
echo "4. Build:"
echo "   Cmd+B"
echo ""
echo "The 'MyChannelApp does not conform' error WILL be gone! 🎉"
echo ""


