#!/bin/bash

# Apple Sign In Verification Script
# This script checks if Apple Sign In is properly configured

echo "🍎 Verifying Apple Sign In Configuration..."

# Check if entitlements file has Apple Sign In capability
if grep -q "com.apple.developer.applesignin" MyChannel/MyChannel.entitlements; then
    echo "✅ Apple Sign In entitlement found in entitlements file"
else
    echo "❌ Apple Sign In entitlement missing from entitlements file"
    echo "   Add this to MyChannel/MyChannel.entitlements:"
    echo "   <key>com.apple.developer.applesignin</key>"
    echo "   <array><string>Default</string></array>"
fi

# Check if AuthenticationServices is imported
if find MyChannel -name "*.swift" -exec grep -l "import AuthenticationServices" {} \; | head -1 > /dev/null; then
    echo "✅ AuthenticationServices framework is imported"
else
    echo "❌ AuthenticationServices framework not found"
fi

# Check if Apple Sign In implementation exists
if find MyChannel -name "*.swift" -exec grep -l "ASAuthorizationAppleIDProvider\|signInWithApple" {} \; | head -1 > /dev/null; then
    echo "✅ Apple Sign In implementation found"
else
    echo "❌ Apple Sign In implementation not found"
fi

# Check if Apple Sign In UI exists
if find MyChannel -name "*.swift" -exec grep -l "applelogo\|Sign in with Apple\|Continue with Apple" {} \; | head -1 > /dev/null; then
    echo "✅ Apple Sign In UI components found"
else
    echo "❌ Apple Sign In UI components not found"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Open MyChannel.xcodeproj in Xcode"
echo "2. Select your project → Signing & Capabilities"
echo "3. Click '+ Capability' and add 'Sign In with Apple'"
echo "4. Make sure your Apple Developer account is selected as the Team"
echo "5. Build and test!"

echo ""
echo "🔗 Apple Sign In is implemented in these files:"
find MyChannel -name "*.swift" -exec grep -l "signInWithApple\|ASAuthorizationAppleIDProvider" {} \; | head -5

