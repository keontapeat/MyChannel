#!/bin/bash

# 🔥🔥🔥 NUCLEAR DEPLOYMENT - DEPLOY EVERYTHING TO FIREBASE 🔥🔥🔥
# This deploys ALL Firebase services: Firestore, Storage, Database, Hosting

echo "🔥🔥🔥 NUCLEAR FIREBASE DEPLOYMENT INITIATED! 🔥🔥🔥"
echo ""

cd /Users/keonta/Documents/MyChannel

echo "📋 Deploying ALL Firebase services:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Firestore Rules (security)"
echo "✅ Firestore Indexes (performance)"
echo "✅ Storage Rules (file uploads)"
echo "✅ Realtime Database Rules (live features)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Deploy EVERYTHING
echo "🚀 Starting deployment..."
firebase deploy --project mychannel-ca26d

if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉🎉🎉 NUCLEAR DEPLOYMENT COMPLETE! 🎉🎉🎉"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "✅ Firestore rules deployed"
    echo "✅ Firestore indexes deployed"
    echo "✅ Storage rules deployed"
    echo "✅ Realtime Database rules deployed"
    echo ""
    echo "🎯 YOUR APP IS NOW FULLY CONFIGURED!"
    echo ""
    echo "📱 TEST YOUR APP:"
    echo "1. Launch MyChannel app"
    echo "2. Videos should load instantly"
    echo "3. Uploads should work"
    echo "4. Live features should work"
    echo "5. Everything should work flawlessly!"
    echo ""
    echo "🔥🔥🔥 NUCLEAR MODE: SUCCESS! 🔥🔥🔥"
else
    echo ""
    echo "❌ Deployment failed - check errors above"
    echo ""
    echo "Try deploying individually:"
    echo "firebase deploy --only firestore --project mychannel-ca26d"
    echo "firebase deploy --only storage --project mychannel-ca26d"
    echo "firebase deploy --only database --project mychannel-ca26d"
fi

