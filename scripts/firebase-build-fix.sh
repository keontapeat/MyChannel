#!/bin/bash
# Fix Firebase Crashlytics build issue

# Set the correct path to GoogleService-Info.plist
export GOOGLE_PLIST_PATH="${SRCROOT}/MyChannel/GoogleService-Info.plist"

# Extract GOOGLE_APP_ID from the plist file if it exists
if [ -f "$GOOGLE_PLIST_PATH" ]; then
    export GOOGLE_APP_ID=$(/usr/libexec/PlistBuddy -c "Print GOOGLE_APP_ID" "$GOOGLE_PLIST_PATH" 2>/dev/null)
else
    # Fallback to hardcoded value if plist is not found
    export GOOGLE_APP_ID="1:124515086975:ios:f3683f5fb93c02d2c3454a"
fi

echo "✅ Firebase build fix applied - GOOGLE_APP_ID: $GOOGLE_APP_ID"
