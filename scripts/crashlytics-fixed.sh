#!/bin/bash

echo "🔥 Firebase Crashlytics Script (Fixed Version)"

# For simulator builds, skip crashlytics entirely
if [ "$PLATFORM_NAME" = "iphonesimulator" ]; then
    echo "📱 Simulator build detected - skipping Crashlytics upload"
    exit 0
fi

# Set up paths
PLIST_PATH="${SRCROOT}/MyChannel/GoogleService-Info.plist"
if [ ! -f "$PLIST_PATH" ]; then
    PLIST_PATH="${SRCROOT}/GoogleService-Info.plist"
fi

# Check if plist exists
if [ ! -f "$PLIST_PATH" ]; then
    echo "⚠️  GoogleService-Info.plist not found at expected locations"
    echo "   Checked: ${SRCROOT}/MyChannel/GoogleService-Info.plist"
    echo "   Checked: ${SRCROOT}/GoogleService-Info.plist"
    exit 0
fi

# Extract GOOGLE_APP_ID using PlistBuddy
GOOGLE_APP_ID=$(/usr/libexec/PlistBuddy -c "Print GOOGLE_APP_ID" "$PLIST_PATH" 2>/dev/null)

if [ -z "$GOOGLE_APP_ID" ]; then
    echo "⚠️  GOOGLE_APP_ID not found in $PLIST_PATH"
    exit 0
fi

echo "✅ Found GOOGLE_APP_ID: $GOOGLE_APP_ID"
export GOOGLE_APP_ID

# Find Crashlytics run script
if [ -f "${PODS_ROOT}/FirebaseCrashlytics/run" ]; then
    echo "🚀 Running Crashlytics upload script..."
    "${PODS_ROOT}/FirebaseCrashlytics/run"
else
    echo "ℹ️  Crashlytics run script not found (this is normal for SPM)"
    echo "   Crashlytics will still work for crash reporting"
fi

echo "✅ Crashlytics script completed successfully"