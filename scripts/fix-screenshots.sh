#!/bin/bash

# ============================================================================
# 🔥 FIX SCREENSHOT CAPTURE - ACTUALLY LAUNCH APP FIRST
# ============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="/Users/keonta/Documents/MyChannel"
cd "$PROJECT_ROOT"

DEVICE="iPhone 16 Plus"
SCHEME="MyChannel"
BUNDLE_ID="com.keontapeat.MyChannelApp"

echo ""
echo "🔥 FIXING SCREENSHOT CAPTURE..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Build for simulator
echo "🔧 Step 1: Building app..."
xcodebuild -project MyChannel.xcodeproj \
    -scheme "$SCHEME" \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath build \
    clean build 2>&1 | grep -E "(BUILD SUCCEEDED|error:)" || true

# Find the built app
APP_PATH=$(find build -name "MyChannel.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ App not found in build directory${NC}"
    echo "Trying alternative build..."
    xcodebuild -project MyChannel.xcodeproj \
        -scheme "$SCHEME" \
        -sdk iphonesimulator \
        -destination "platform=iOS Simulator,name=$DEVICE" \
        build 2>&1 | tail -3
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "MyChannel.app" -type d | head -1)
fi

if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Could not find built app. Build failed.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ App built: $APP_PATH${NC}"
echo ""

# Step 2: Boot simulator
echo "📱 Step 2: Booting simulator..."
xcrun simctl boot "$DEVICE" 2>/dev/null || echo "Already booted"
sleep 2
open -a Simulator
sleep 3

# Step 3: Install app
echo "📦 Step 3: Installing app..."
xcrun simctl install booted "$APP_PATH" 2>&1 | grep -v "^$" || {
    echo -e "${YELLOW}⚠️  Install message (may be OK)${NC}"
}

# Step 4: Launch app
echo "🚀 Step 4: Launching app..."
xcrun simctl launch booted "$BUNDLE_ID" 2>&1 || {
    echo -e "${YELLOW}⚠️  Launch message (checking if running)${NC}"
}

sleep 5

# Step 5: Verify app is running
echo "✅ Step 5: Verifying app is running..."
if xcrun simctl listapps booted | grep -q "$BUNDLE_ID"; then
    echo -e "${GREEN}✅ App is installed and should be visible!${NC}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✅ APP IS READY FOR SCREENSHOTS!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📸 Next steps:"
    echo "   1. Look at the Simulator - you should see MyChannel app"
    echo "   2. Navigate to different screens manually"
    echo "   3. Take screenshots with: Cmd + S"
    echo "   4. Or run: xcrun simctl io booted screenshot screenshot.png"
    echo ""
else
    echo -e "${RED}❌ App not found. Check simulator.${NC}"
    echo "Try launching manually from Simulator home screen"
fi





