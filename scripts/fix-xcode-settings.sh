#!/bin/bash

echo "🛠️  Fixing Xcode Build Settings for Firebase Crashlytics..."

PROJECT_FILE="/Users/keonta/Documents/MyChannel/MyChannel.xcodeproj/project.pbxproj"

# Backup the original file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup"

# Add ENABLE_USER_SCRIPT_SANDBOXING = NO to build settings
sed -i '' 's/ENABLE_TESTABILITY = YES;/ENABLE_TESTABILITY = YES;\
				ENABLE_USER_SCRIPT_SANDBOXING = NO;/' "$PROJECT_FILE"

echo "✅ Updated project settings to disable script sandboxing"
echo "📁 Backup saved as project.pbxproj.backup"
echo ""
echo "Now run: xcodebuild -project MyChannel.xcodeproj -scheme MyChannel -sdk iphonesimulator"