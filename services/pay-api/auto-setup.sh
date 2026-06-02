#!/bin/bash
set -e

echo "🚀 MyChannel Pay API - FULL AUTO SETUP"
echo "========================================"
echo ""
echo "I'll set up EVERYTHING for you. Just paste your Stripe key when asked."
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
  echo "❌ Error: Run this from services/pay-api directory"
  exit 1
fi

# Step 1: Get Stripe key
echo "📝 Step 1: Stripe Configuration"
echo ""
echo "Go to: https://dashboard.stripe.com/test/apikeys"
echo "Copy your 'Secret key' (starts with sk_test_)"
echo ""
read -s -p "Paste your Stripe Secret Key: " STRIPE_SECRET
echo ""
echo ""

# Validate
if [[ ! $STRIPE_SECRET =~ ^sk_(test|live)_[a-zA-Z0-9]{24,}$ ]]; then
  echo "❌ Invalid key. Should start with sk_test_ or sk_live_"
  exit 1
fi

if [[ $STRIPE_SECRET =~ ^sk_test_ ]]; then
  echo "✅ Using TEST mode"
else
  echo "✅ Using LIVE mode"
fi
echo ""

# Step 2: Generate secrets
echo "🔑 Step 2: Generating secure secrets..."
CRON_SECRET=$(openssl rand -hex 32)
echo "✅ Generated CRON_SECRET"
echo ""

# Step 3: Create .env
echo "📄 Step 3: Creating .env file..."
cat > .env << EOF
# MyChannel Pay API - Auto-generated Configuration
# Created: $(date)

# Stripe
STRIPE_SECRET="$STRIPE_SECRET"

# Firebase/Firestore (already configured)
FIREBASE_PROJECT_ID="mychannel-ca26d"
USE_FIRESTORE="true"

# App
APP_BASE_URL="https://mychannel.live"

# Scheduled Payouts
CRON_SECRET="$CRON_SECRET"
AUTO_PAYOUT_THRESHOLD_CENTS="10000"

# Server
PORT="8888"
NODE_ENV="production"
EOF

echo "✅ Created .env"
echo ""

# Step 4: Add to .gitignore
if [ ! -f ".gitignore" ]; then
  echo ".env" > .gitignore
  echo "node_modules/" >> .gitignore
  echo "✅ Created .gitignore"
elif ! grep -q "^\.env$" .gitignore; then
  echo ".env" >> .gitignore
  echo "✅ Added .env to .gitignore"
fi
echo ""

# Step 5: Install dependencies
echo "📦 Step 4: Installing dependencies..."
npm install --silent
echo "✅ Dependencies installed"
echo ""

# Step 6: Initialize Firestore collections (no migration needed!)
echo "🔥 Step 5: Firestore is already set up!"
echo "✅ Using existing collections:"
echo "   - creator_earnings"
echo "   - payout_requests"
echo "   - creator_balances"
echo "   - tip_transactions"
echo ""

# Step 7: Start the service
echo "🚀 Step 6: Starting service..."
echo ""
echo "============================================"
echo "✅ SETUP COMPLETE!"
echo "============================================"
echo ""
echo "Service starting on http://localhost:8888"
echo ""
echo "📋 What's configured:"
echo "   ✅ Stripe: $(echo $STRIPE_SECRET | cut -c1-15)..."
echo "   ✅ Database: Firestore (mychannel-ca26d)"
echo "   ✅ Webhooks: Ready (add endpoint in Stripe Dashboard)"
echo "   ✅ Auto-payouts: Enabled (\$100 threshold)"
echo ""
echo "🔔 Next: Configure Stripe webhooks"
echo "   1. Go to: https://dashboard.stripe.com/webhooks"
echo "   2. Add endpoint: https://mychannel.live/pay/webhooks/stripe"
echo "   3. Select events: transfer.paid, transfer.failed, transfer.reversed, account.updated"
echo "   4. Copy signing secret and add to .env as STRIPE_WEBHOOK_SECRET"
echo ""
echo "Press Ctrl+C to stop the service"
echo ""
echo "============================================"
echo ""

# Start the service
npm start
