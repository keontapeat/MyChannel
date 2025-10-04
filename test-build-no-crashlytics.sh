#!/bin/bash

echo "🚀 Testing MyChannel build without Crashlytics..."

# Build with Crashlytics disabled by skipping the script phase
xcodebuild -project MyChannel.xcodeproj \
           -scheme MyChannel \
           -configuration Debug \
           -sdk iphonesimulator \
           -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
           CODE_SIGNING_ALLOWED=NO \
           ENABLE_USER_SCRIPT_SANDBOXING=NO \
           -skipPackagePluginValidation \
           2>&1 | grep -v "sandbox-exec" | tail -20

