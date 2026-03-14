#!/bin/bash

# =============================================================================
# 🚀 QUICK REBUILD SCRIPT - Fix Launch Timeout Issues
# =============================================================================

set -e  # Exit on any error

echo "🧹 Cleaning Xcode build artifacts..."

# Kill Xcode if running
killall -9 Xcode 2>/dev/null && echo "✅ Killed Xcode" || echo "ℹ️  Xcode not running"

# Kill simulator if running
killall -9 Simulator 2>/dev/null && echo "✅ Killed Simulator" || echo "ℹ️  Simulator not running"

# Kill app if running
killall -9 "MyChannel" 2>/dev/null && echo "✅ Killed MyChannel app" || echo "ℹ️  MyChannel not running"

echo ""
echo "🗑️  Removing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MyChannel-* || true

echo "🗑️  Clearing Xcode caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode || true

echo "📱 Resetting simulators..."
xcrun simctl shutdown all 2>/dev/null || true
xcrun simctl erase all 2>/dev/null || true

echo ""
echo "💾 Checking disk space..."
df -h / | grep "disk1s1s1"

echo ""
echo "✅ CLEANUP COMPLETE!"
echo ""
echo "📋 NEXT STEPS:"
echo "1. Wait 10 seconds"
echo "2. Open Xcode: open MyChannel.xcodeproj"
echo "3. Product → Clean Build Folder (Cmd+Shift+K)"
echo "4. File → Packages → Reset Package Caches"
echo "5. Wait for packages to resolve"
echo "6. Product → Build (Cmd+B)"
echo "7. Select iPhone 16 (not Pro) as target"
echo "8. Product → Run (Cmd+R)"
echo ""
echo "⏱️  First build may take 5-10 minutes. Be patient!"
echo ""

# Wait 10 seconds
echo "⏳ Waiting 10 seconds before opening Xcode..."
sleep 10

# Open Xcode
echo "🚀 Opening Xcode..."
cd "$(dirname "$0")/.."
open MyChannel.xcodeproj

echo "✅ Done! Follow the next steps in Xcode."
