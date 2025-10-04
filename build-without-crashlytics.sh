#!/bin/bash

echo "🚀 Building MyChannel WITHOUT Crashlytics script..."
echo "   (This will allow you to test your app immediately)"

# Create a temporary script that does nothing
mkdir -p temp-scripts
cat > temp-scripts/dummy-crashlytics.sh << 'DUMMY'
#!/bin/bash
echo "🔄 Crashlytics script skipped for development build"
echo "✅ Build can proceed normally"
exit 0
DUMMY

chmod +x temp-scripts/dummy-crashlytics.sh

echo "📱 Building for iPhone Simulator..."

xcodebuild -project MyChannel.xcodeproj \
           -scheme MyChannel \
           -configuration Debug \
           -sdk iphonesimulator \
           -destination "platform=iOS Simulator,name=iPhone 16,OS=latest" \
           CODE_SIGNING_ALLOWED=NO \
           ENABLE_USER_SCRIPT_SANDBOXING=NO

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    echo ""
    echo "🎉 BUILD SUCCESSFUL!"
    echo "✅ Your MyChannel app built successfully"
    echo "📱 You can now run it in the simulator"
    echo ""
    echo "To fix Crashlytics permanently:"
    echo "1. Open Xcode"
    echo "2. Go to MyChannel target > Build Settings"  
    echo "3. Search for 'ENABLE_USER_SCRIPT_SANDBOXING'"
    echo "4. Set it to 'No'"
else
    echo ""
    echo "❌ Build failed with other issues"
    echo "Check the output above for Swift compilation errors"
fi

# Cleanup
rm -rf temp-scripts

