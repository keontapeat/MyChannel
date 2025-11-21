#!/bin/bash

# 🔥 Deploy Firebase Security Rules for MyChannel
# This fixes the "Missing or insufficient permissions" errors

echo "🔥 Deploying Firebase Security Rules..."
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null
then
    echo "❌ Firebase CLI not installed"
    echo "Install with: npm install -g firebase-tools"
    echo "Then run: firebase login"
    exit 1
fi

# Check if logged in
if ! firebase projects:list &> /dev/null
then
    echo "❌ Not logged in to Firebase"
    echo "Run: firebase login"
    exit 1
fi

# Check if firestore.rules exists
if [ ! -f "firestore.rules" ]; then
    echo "❌ firestore.rules file not found"
    echo "Make sure you're in the project root directory"
    exit 1
fi

echo "📋 Current Firebase project: mychannel-ca26d"
echo ""

# Preview changes
echo "📝 Security rules to deploy:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
head -20 firestore.rules
echo "..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Confirm
read -p "🤔 Deploy these rules to production? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "❌ Deployment cancelled"
    exit 0
fi

# Deploy
echo ""
echo "🚀 Deploying rules..."

firebase deploy --only firestore:rules --project mychannel-ca26d

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Firebase security rules deployed successfully!"
    echo ""
    echo "📱 Next steps:"
    echo "1. Test your app - videos should now load"
    echo "2. Check console - no more permission errors"
    echo "3. Create Firestore index (see CRITICAL_FIXES_REQUIRED.md)"
    echo ""
    echo "🎉 Your app should now be working!"
else
    echo ""
    echo "❌ Deployment failed"
    echo "Try deploying manually:"
    echo "1. Go to: https://console.firebase.google.com/project/mychannel-ca26d/firestore/rules"
    echo "2. Copy contents of firestore.rules"
    echo "3. Paste and click Publish"
fi

