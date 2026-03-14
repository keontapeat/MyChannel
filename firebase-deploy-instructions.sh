#!/bin/bash
# 🔥 FIREBASE STORAGE RULES - ONE-CLICK DEPLOY

echo "🚀 MyChannel Firebase Storage Rules Deployment"
echo "=============================================="
echo ""
echo "📋 What this deploys:"
echo "   - Profile picture upload permissions"
echo "   - Banner image upload permissions"
echo "   - All user media storage rules"
echo ""
echo "⚡ Running deployment..."
echo ""

firebase deploy --only storage --project mychannel-ca26d

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! Storage rules deployed!"
    echo "📸 Profile pictures can now be saved!"
    echo ""
    echo "🧪 Test by:"
    echo "   1. Open MyChannel app"
    echo "   2. Go to Profile → Edit Profile"
    echo "   3. Upload a profile picture"
    echo "   4. Tap Save"
    echo ""
else
    echo ""
    echo "❌ Deployment failed. Try manual method:"
    echo "   https://console.firebase.google.com/project/mychannel-ca26d/storage/rules"
    echo ""
fi
