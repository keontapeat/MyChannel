#!/bin/bash

# MyChannel Web Deployment Script
# Automatically builds and deploys to Firebase Hosting

echo "🚀 Starting MyChannel Web Deployment..."

# Build Next.js static export
echo "📦 Building Next.js app..."
npm run build

# Check if build succeeded
if [ $? -eq 0 ]; then
  echo "✅ Build successful!"
  
  # Deploy to Firebase Hosting
  echo "🔥 Deploying to Firebase Hosting..."
  firebase deploy --only hosting
  
  if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    echo "🌐 Your website is live at: https://mychannel.live"
  else
    echo "❌ Deployment failed!"
    exit 1
  fi
else
  echo "❌ Build failed!"
  exit 1
fi

