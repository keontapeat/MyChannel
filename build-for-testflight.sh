#!/bin/bash

# MyChannel TestFlight Build Script
# This script helps you build and archive your app for TestFlight distribution

set -e  # Exit on any error

echo "🚀 Building MyChannel for TestFlight..."

# Configuration
PROJECT_NAME="MyChannel"
SCHEME="MyChannel"
WORKSPACE_PATH="MyChannel.xcodeproj"
ARCHIVE_PATH="./build/MyChannel.xcarchive"
EXPORT_PATH="./build/export"

# Create build directory
mkdir -p build

echo "📱 Cleaning previous builds..."
xcodebuild clean -project "$WORKSPACE_PATH" -scheme "$SCHEME"

echo "🔨 Building and archiving..."
xcodebuild archive \
    -project "$WORKSPACE_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic

echo "📦 Exporting for App Store distribution..."

# Create export options plist
cat > ./build/ExportOptions.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
    <key>teamID</key>
    <string>8KPXZ859S7</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist ./build/ExportOptions.plist \
    -allowProvisioningUpdates

echo "✅ Build completed successfully!"
echo "📁 Archive location: $ARCHIVE_PATH"
echo "📁 Export location: $EXPORT_PATH"
echo ""
echo "🎯 Next steps:"
echo "1. Open Xcode and go to Window > Organizer"
echo "2. Select your archive and click 'Distribute App'"
echo "3. Choose 'App Store Connect' and follow the prompts"
echo "4. Or use: xcrun altool --upload-app -f \"$EXPORT_PATH/MyChannel.ipa\" -u your-apple-id@email.com"
echo ""
echo "🔗 After upload, visit https://appstoreconnect.apple.com to:"
echo "   - Add TestFlight testers"
echo "   - Submit for beta review"
echo "   - Distribute to testers"

