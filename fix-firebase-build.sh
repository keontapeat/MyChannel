#!/bin/bash
echo "🔧 Fixing Firebase Crashlytics build issue..."

# Method 1: Set build setting permanently
echo "Setting ENABLE_USER_SCRIPT_SANDBOXING = NO"
xcrun xcodebuild -project MyChannel.xcodeproj -target MyChannel -configuration Debug -showBuildSettings | grep ENABLE_USER_SCRIPT_SANDBOXING

# Create a temporary pbxproj modification script
echo "Modifying project settings..."

