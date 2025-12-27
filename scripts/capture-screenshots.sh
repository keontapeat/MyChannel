#!/bin/bash

# ============================================================================
# 📸 MyChannel App Store Screenshot Automation Script
# ============================================================================
# This script captures screenshots for all required App Store device sizes
# Run from project root: ./scripts/capture-screenshots.sh
# ============================================================================

set -e

echo "📸 MyChannel Screenshot Capture Script"
echo "========================================"
echo ""

# Create output directory
SCREENSHOT_DIR="./AppStoreScreenshots"
mkdir -p "$SCREENSHOT_DIR"

# Device configurations for App Store
declare -a DEVICES=(
    "iPhone 15 Pro Max"      # 6.7 inch - REQUIRED
    "iPhone 14 Plus"         # 6.7 inch alternative  
    "iPhone 11 Pro Max"      # 6.5 inch - REQUIRED
    "iPhone 8 Plus"          # 5.5 inch - REQUIRED
    "iPad Pro (12.9-inch) (6th generation)"  # iPad 12.9 - REQUIRED
    "iPad Pro (11-inch) (4th generation)"    # iPad 11 - REQUIRED
)

# Scenes to capture (customize these based on your app)
declare -a SCENES=(
    "Home"
    "VideoPlayer"
    "CreatorStudio"
    "Upload"
    "Profile"
)

echo "🔧 Building app for simulator..."
xcodebuild -project MyChannel.xcodeproj \
    -scheme MyChannel \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro Max' \
    -derivedDataPath build \
    build 2>/dev/null || {
        echo "⚠️  Build failed. Make sure Xcode and simulators are installed."
        exit 1
    }

echo ""
echo "📱 Available simulators:"
xcrun simctl list devices available | grep -E "(iPhone|iPad)"
echo ""

# Function to capture screenshot
capture_screenshot() {
    local device="$1"
    local scene="$2"
    local filename="$3"
    
    echo "📸 Capturing: $device - $scene"
    
    # Boot simulator if not running
    xcrun simctl boot "$device" 2>/dev/null || true
    
    # Wait for boot
    sleep 2
    
    # Take screenshot
    xcrun simctl io "$device" screenshot "$SCREENSHOT_DIR/$filename"
    
    echo "   ✅ Saved: $filename"
}

echo ""
echo "📸 Starting screenshot capture..."
echo "   Navigate to each screen manually and press Enter to capture."
echo ""

# Interactive capture mode
for device in "${DEVICES[@]}"; do
    device_safe=$(echo "$device" | tr ' ' '_' | tr -d '()' | tr -d '-')
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 Device: $device"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Boot the device
    echo "   Booting simulator..."
    xcrun simctl boot "$device" 2>/dev/null || true
    
    # Open simulator
    open -a Simulator
    sleep 3
    
    for scene in "${SCENES[@]}"; do
        echo ""
        echo "   📍 Navigate to: $scene"
        read -p "   Press Enter when ready to capture..." 
        
        filename="${device_safe}_${scene}.png"
        xcrun simctl io booted screenshot "$SCREENSHOT_DIR/$filename"
        echo "   ✅ Captured: $filename"
    done
    
    # Shutdown this device
    xcrun simctl shutdown "$device" 2>/dev/null || true
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Screenshot capture complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Screenshots saved to: $SCREENSHOT_DIR"
echo ""
ls -la "$SCREENSHOT_DIR"
echo ""
echo "📋 Next steps:"
echo "   1. Review screenshots in $SCREENSHOT_DIR"
echo "   2. Add text overlays/marketing using Figma or similar"
echo "   3. Upload to App Store Connect"
echo ""
echo "📐 Required sizes:"
echo "   • iPhone 6.7\": 1290 × 2796 px"
echo "   • iPhone 6.5\": 1242 × 2688 px"
echo "   • iPhone 5.5\": 1242 × 2208 px"
echo "   • iPad 12.9\": 2048 × 2732 px"
echo ""




