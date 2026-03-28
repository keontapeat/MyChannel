#!/bin/bash
#
# validate-bundle-id.sh
# Pre-build validation to ensure bundle ID matches App Store Connect
# Add to Build Phases as a "Run Script" before "Compile Sources"
#

EXPECTED_BUNDLE_ID="com.keontapeat.MyChannelApp"
PLIST_PATH="${SRCROOT}/MyChannel/Info.plist"

# Check if we're in Xcode build context
if [ -z "$PRODUCT_BUNDLE_IDENTIFIER" ]; then
    # Manual run from terminal
    echo "⚠️  Not in Xcode build context, skipping bundle ID validation"
    exit 0
fi

if [ "$PRODUCT_BUNDLE_IDENTIFIER" != "$EXPECTED_BUNDLE_ID" ]; then
    echo "❌ ERROR: Bundle ID mismatch!"
    echo "   Expected: $EXPECTED_BUNDLE_ID"
    echo "   Actual:   $PRODUCT_BUNDLE_IDENTIFIER"
    echo ""
    echo "🛠️  Fix: Update PRODUCT_BUNDLE_IDENTIFIER in Build Settings"
    echo "   This must match the App Store Connect app record."
    exit 1
fi

echo "✅ Bundle ID validated: $PRODUCT_BUNDLE_IDENTIFIER"
exit 0
