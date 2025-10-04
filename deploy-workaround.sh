#!/bin/bash

# Firebase CLI finalize workaround script
# This script works around the 404 finalize bug by using preview channels

set -e

echo "🚀 Starting Firebase deployment workaround..."

# Generate a unique channel name
CHANNEL_NAME="deploy-$(date +%Y%m%d-%H%M%S)"

echo "📦 Deploying to preview channel: $CHANNEL_NAME"

# Deploy to preview channel (this works even when finalize fails)
firebase hosting:channel:deploy "$CHANNEL_NAME" --expires 1d || {
    echo "❌ Preview deploy failed"
    exit 1
}

echo "🔄 Cloning preview channel to live..."

# Clone the preview channel to live (this bypasses the finalize bug)
firebase hosting:clone "mychannel-ca26d:$CHANNEL_NAME" "mychannel-ca26d:live" || {
    echo "❌ Clone to live failed"
    exit 1
}

echo "✅ Deployment successful!"
echo "🌐 Your site is now live at: https://mychannel.live"

# Clean up the temporary preview channel
echo "🧹 Cleaning up preview channel..."
firebase hosting:channel:delete "$CHANNEL_NAME" --force || {
    echo "⚠️  Warning: Could not delete preview channel $CHANNEL_NAME"
}

echo "🎉 All done!"
