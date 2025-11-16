#!/bin/bash
# 🔥 MYCHANNEL WEB DEPLOYMENT AUTOPILOT 🔥

echo "🚀 Starting MyChannel Web Deployment Autopilot..."
echo ""

# Step 1: Copy logo
echo "📍 Step 1/4: Copying MyChannel logo..."
cp "/Users/keonta/Documents/MyChannel/MyChannel/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" "/Users/keonta/Documents/MyChannel/web-v2/public/logo.png"
if [ $? -eq 0 ]; then
    echo "✅ Logo copied successfully!"
else
    echo "⚠️  Warning: Logo copy failed, but continuing..."
fi
echo ""

# Step 2: Clean build artifacts
echo "🧹 Step 2/4: Cleaning build artifacts..."
cd /Users/keonta/Documents/MyChannel/web-v2
rm -rf .next out node_modules/.cache
echo "✅ Clean complete!"
echo ""

# Step 3: Build the site
echo "🏗️  Step 3/4: Building site..."
npm run build
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed! Check errors above."
    exit 1
fi
echo ""

# Step 4: Deploy to Firebase
echo "🚀 Step 4/4: Deploying to Firebase (mychannel-ca26d)..."
firebase deploy --project mychannel-ca26d --only hosting
if [ $? -eq 0 ]; then
    echo ""
    echo "🎉🎉🎉 DEPLOYMENT COMPLETE! 🎉🎉🎉"
    echo "🌐 Your site is LIVE at: https://mychannel-ca26d.web.app"
    echo "🔥 BILLION-DOLLAR UI IS NOW DEPLOYED! 🔥"
else
    echo "❌ Deployment failed! Check errors above."
    exit 1
fi


