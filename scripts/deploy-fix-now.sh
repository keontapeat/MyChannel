#!/bin/bash

# 🎯 ONE-COMMAND FIX FOR PROFILE PICTURE SAVING
# Run this script to deploy the fix to Firebase

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔥 PROFILE PICTURE FIX - AUTOPILOT DEPLOYMENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ Issue identified: Firebase Storage Rules mismatch"
echo "✅ Fix applied: storage.rules updated with user-avatars/* path"
echo "⏳ Status: Ready to deploy"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Navigate to project directory
cd "$(dirname "$0")/.." || exit 1

# Check if storage.rules exists
if [ ! -f "storage.rules" ]; then
    echo "❌ ERROR: storage.rules file not found"
    echo "   Expected location: $(pwd)/storage.rules"
    exit 1
fi

echo "📋 Found storage.rules file"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ Firebase CLI not installed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Install with: npm install -g firebase-tools"
    echo ""
    echo "OR use Firebase Console instead (opens in browser)..."
    sleep 2
    open "https://console.firebase.google.com/project/mychannel-ca26d/storage/mychannel-ca26d.firebasestorage.app/rules"
    echo ""
    echo "✅ Opened Firebase Console in browser"
    echo ""
    echo "Manual steps:"
    echo "1. Sign in to Firebase Console"
    echo "2. Click 'Rules' tab"
    echo "3. Copy contents from: $(pwd)/storage.rules"
    echo "4. Paste into editor and click 'Publish'"
    echo ""
    exit 0
fi

echo "✅ Firebase CLI installed"
echo ""

# Check Firebase authentication
echo "🔐 Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔑 FIREBASE LOGIN REQUIRED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Attempting to open Firebase login..."
    echo "(This will open your browser)"
    echo ""
    
    # Try to login
    if firebase login --no-localhost; then
        echo ""
        echo "✅ Login successful!"
    else
        echo ""
        echo "❌ Login failed or cancelled"
        echo ""
        echo "Please login manually:"
        echo "   firebase login"
        echo ""
        echo "Then run this script again:"
        echo "   ./scripts/deploy-fix-now.sh"
        echo ""
        exit 1
    fi
fi

echo "✅ Firebase authentication verified"
echo ""

# Show what will be deployed
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 DEPLOYMENT DETAILS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Project: mychannel-ca26d"
echo "Target: Firebase Storage Rules"
echo "File: storage.rules"
echo ""
echo "New rules added:"
echo "  • user-avatars/* (profile pictures)"
echo "  • user-banners/* (banner images)"
echo ""

# Confirm deployment
read -p "🚀 Deploy now? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "❌ Deployment cancelled by user"
    echo ""
    echo "To deploy later, run:"
    echo "   firebase deploy --only storage"
    echo ""
    exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 DEPLOYING TO FIREBASE..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Deploy storage rules
if firebase deploy --only storage --project mychannel-ca26d; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ ✅ ✅ DEPLOYMENT SUCCESSFUL! ✅ ✅ ✅"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎉 Profile picture saving is now FIXED!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 TEST THE FIX"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Open MyChannel app"
    echo "2. Go to Profile → Edit Profile"
    echo "3. Tap profile picture"
    echo "4. Select new image"
    echo "5. Tap Save"
    echo ""
    echo "Expected: Image uploads successfully and persists!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
else
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ DEPLOYMENT FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Common solutions:"
    echo ""
    echo "1. Re-authenticate:"
    echo "   firebase login --reauth"
    echo ""
    echo "2. Check permissions:"
    echo "   firebase projects:list"
    echo ""
    echo "3. Try Firebase Console instead:"
    open "https://console.firebase.google.com/project/mychannel-ca26d/storage/mychannel-ca26d.firebasestorage.app/rules"
    echo "   ✅ Opened in browser"
    echo ""
    echo "4. Manual deployment:"
    echo "   - Copy contents from: $(pwd)/storage.rules"
    echo "   - Paste into Firebase Console"
    echo "   - Click 'Publish'"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    exit 1
fi






