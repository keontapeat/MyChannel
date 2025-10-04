#!/bin/bash

# Enhanced Firebase Crashlytics Script Wrapper
# This script ensures proper environment setup for Firebase Crashlytics

echo "🚀 Firebase Crashlytics Wrapper Script Starting..."

# Set up environment variables
export SRCROOT="${SRCROOT:-$(pwd)}"
export BUILT_PRODUCTS_DIR="${BUILT_PRODUCTS_DIR:-${SRCROOT}/Build/Products}"
export DWARF_DSYM_FOLDER_PATH="${DWARF_DSYM_FOLDER_PATH:-${BUILT_PRODUCTS_DIR}}"
export DWARF_DSYM_FILE_NAME="${DWARF_DSYM_FILE_NAME:-MyChannel.app.dSYM}"
export INFOPLIST_FILE="${INFOPLIST_FILE:-MyChannel/Info.plist}"

# Locate GoogleService-Info.plist
GOOGLE_PLIST_PATH="${SRCROOT}/MyChannel/GoogleService-Info.plist"
if [ ! -f "$GOOGLE_PLIST_PATH" ]; then
    GOOGLE_PLIST_PATH="${SRCROOT}/GoogleService-Info.plist"
fi

if [ ! -f "$GOOGLE_PLIST_PATH" ]; then
    echo "⚠️ Warning: GoogleService-Info.plist not found. Skipping Crashlytics script."
    echo "Looking for file at: $GOOGLE_PLIST_PATH"
    exit 0
fi

# Extract GOOGLE_APP_ID from plist
GOOGLE_APP_ID=$(/usr/libexec/PlistBuddy -c "Print GOOGLE_APP_ID" "$GOOGLE_PLIST_PATH" 2>/dev/null)

if [ -z "$GOOGLE_APP_ID" ]; then
    echo "⚠️ Warning: Could not extract GOOGLE_APP_ID from $GOOGLE_PLIST_PATH"
    exit 0
fi

echo "✅ Found GOOGLE_APP_ID: $GOOGLE_APP_ID"
export GOOGLE_APP_ID

# Check if we're in a real build (not a preview/test build)
if [ "$CONFIGURATION" = "Debug" ] && [ -n "$BUILD_FOR_DEVICE" ]; then
    echo "📱 Running in device build mode - executing Crashlytics script"
    
    # Find the Crashlytics run script
    CRASHLYTICS_SCRIPT="${PODS_ROOT}/FirebaseCrashlytics/run"
    
    if [ ! -f "$CRASHLYTICS_SCRIPT" ]; then
        # Try SPM location
        CRASHLYTICS_SCRIPT=$(find "${SRCROOT}/.." -name "run" -path "*/FirebaseCrashlytics/*" 2>/dev/null | head -1)
    fi
    
    if [ -f "$CRASHLYTICS_SCRIPT" ]; then
        echo "🔥 Executing Crashlytics script: $CRASHLYTICS_SCRIPT"
        "$CRASHLYTICS_SCRIPT"
    else
        echo "ℹ️ Crashlytics run script not found. This is normal for simulator builds."
    fi
else
    echo "🔄 Simulator build detected - skipping Crashlytics upload"
fi

echo "✅ Firebase Crashlytics Wrapper Script Complete"
