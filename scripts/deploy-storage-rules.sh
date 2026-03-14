#!/bin/bash

# 🔥 Firebase Storage Rules Deployment Script
# This script will help you deploy the updated storage rules

echo "🔥 Firebase Storage Rules Deployment"
echo "===================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed"
    echo "   Install it with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI is installed"
echo ""

# Check if user is authenticated
echo "🔐 Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    echo "❌ Not authenticated to Firebase"
    echo ""
    echo "Please authenticate by running ONE of these commands:"
    echo ""
    echo "Option 1 (Interactive - opens browser):"
    echo "   firebase login"
    echo ""
    echo "Option 2 (Re-authenticate):"
    echo "   firebase login --reauth"
    echo ""
    echo "Then run this script again."
    exit 1
fi

echo "✅ Firebase authentication verified"
echo ""

# Show current project
echo "📋 Current Firebase project:"
firebase projects:list | grep mychannel-ca26d || echo "   Project: mychannel-ca26d"
echo ""

# Confirm deployment
echo "📝 This will deploy the following rules:"
echo "   - user-avatars/* (profile pictures)"
echo "   - user-banners/* (banner images)"
echo ""
read -p "Deploy storage rules? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Deploy storage rules
echo ""
echo "🚀 Deploying storage rules..."
firebase deploy --only storage --project mychannel-ca26d

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ ✅ ✅ DEPLOYMENT SUCCESSFUL! ✅ ✅ ✅"
    echo ""
    echo "🎉 Profile picture saving is now fixed!"
    echo ""
    echo "Next steps:"
    echo "1. Open MyChannel app"
    echo "2. Go to Profile → Edit Profile"
    echo "3. Change your profile picture"
    echo "4. Tap Save"
    echo "5. Verify the image saves and persists"
    echo ""
else
    echo ""
    echo "❌ Deployment failed"
    echo "Check the error message above"
    echo ""
    echo "Common solutions:"
    echo "1. Run: firebase login --reauth"
    echo "2. Verify you have permission to deploy"
    echo "3. Check storage.rules file exists"
    echo "4. Try deploying via Firebase Console instead"
    echo ""
fi






