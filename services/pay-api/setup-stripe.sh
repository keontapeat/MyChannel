#!/bin/bash
set -e

echo "🔐 MyChannel Pay API - Stripe Configuration"
echo "============================================"
echo ""

# Check if .env file exists
if [ -f ".env" ]; then
  echo "⚠️  .env file already exists. Creating backup..."
  cp .env .env.backup.$(date +%s)
  echo "✅ Backup created: .env.backup.*"
  echo ""
fi

# Get Stripe secret key
echo "📝 Step 1: Get your Stripe Secret Key"
echo ""
echo "1. Go to: https://dashboard.stripe.com/apikeys"
echo "2. Copy your 'Secret key' (starts with sk_test_ or sk_live_)"
echo "3. Paste it below (input will be hidden for security)"
echo ""
read -s -p "Enter your Stripe Secret Key: " STRIPE_SECRET
echo ""
echo ""

# Validate Stripe key format
if [[ ! $STRIPE_SECRET =~ ^sk_(test|live)_[a-zA-Z0-9]{24,}$ ]]; then
  echo "❌ Invalid Stripe key format. Should start with sk_test_ or sk_live_"
  exit 1
fi

# Determine if test or live mode
if [[ $STRIPE_SECRET =~ ^sk_test_ ]]; then
  MODE="TEST"
  echo "🧪 Using TEST mode (sk_test_...)"
else
  MODE="LIVE"
  echo "🔴 Using LIVE mode (sk_live_...)"
fi
echo ""

# Get database URL
echo "📝 Step 2: Database Configuration"
echo ""
echo "Enter your PostgreSQL connection string:"
echo "Format: postgresql://user:password@host:5432/database"
echo ""
read -p "DATABASE_URL: " DATABASE_URL
echo ""

# Get app base URL
echo "📝 Step 3: App Configuration"
echo ""
read -p "Enter your production domain (e.g., https://mychannel.live): " APP_BASE_URL
echo ""

# Generate cron secret
CRON_SECRET=$(openssl rand -hex 32)
echo "🔑 Generated secure CRON_SECRET: ${CRON_SECRET:0:16}..."
echo ""

# Create .env file
cat > .env << EOF
# MyChannel Pay API - Environment Configuration
# Generated: $(date)
# Mode: $MODE

# ============================================
# REQUIRED CONFIGURATION
# ============================================

# Stripe Configuration
STRIPE_SECRET="$STRIPE_SECRET"

# Database Configuration
DATABASE_URL="$DATABASE_URL"

# App Configuration
APP_BASE_URL="$APP_BASE_URL"

# ============================================
# OPTIONAL CONFIGURATION
# ============================================

# Webhook Configuration (add after setting up Stripe webhooks)
# STRIPE_WEBHOOK_SECRET="whsec_..."

# Scheduled Payouts
CRON_SECRET="$CRON_SECRET"
AUTO_PAYOUT_THRESHOLD_CENTS="10000"  # \$100 default

# Server Configuration
PORT="8888"
NODE_ENV="production"

# ============================================
# NOTES
# ============================================
# 1. Never commit this file to git (.env is in .gitignore)
# 2. Add STRIPE_WEBHOOK_SECRET after configuring webhooks in Stripe Dashboard
# 3. Keep CRON_SECRET secure - it's used to authenticate scheduled payout jobs
EOF

echo "✅ Configuration saved to .env"
echo ""

# Create .env.example for reference
cat > .env.example << EOF
# MyChannel Pay API - Environment Configuration Template
# Copy this file to .env and fill in your values

# Stripe Configuration
STRIPE_SECRET="sk_test_or_sk_live_your_key_here"
STRIPE_WEBHOOK_SECRET="whsec_your_webhook_secret_here"

# Database Configuration
DATABASE_URL="postgresql://user:password@host:5432/database"

# App Configuration
APP_BASE_URL="https://mychannel.live"

# Scheduled Payouts
CRON_SECRET="your_secure_random_string_here"
AUTO_PAYOUT_THRESHOLD_CENTS="10000"

# Server Configuration
PORT="8888"
NODE_ENV="production"
EOF

echo "✅ Created .env.example template"
echo ""

# Add to .gitignore if not already there
if [ ! -f ".gitignore" ]; then
  echo ".env" > .gitignore
  echo "✅ Created .gitignore"
elif ! grep -q "^\.env$" .gitignore; then
  echo ".env" >> .gitignore
  echo "✅ Added .env to .gitignore"
fi
echo ""

# Show next steps
echo "============================================"
echo "✅ SETUP COMPLETE!"
echo "============================================"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Run database migration:"
echo "   npm install"
echo "   node src/migrate.js"
echo ""
echo "2. Start the service:"
echo "   npm start"
echo "   # Or use: ./start.sh"
echo ""
echo "3. Configure Stripe webhooks:"
echo "   a. Go to: https://dashboard.stripe.com/webhooks"
echo "   b. Click 'Add endpoint'"
echo "   c. URL: $APP_BASE_URL/pay/webhooks/stripe"
echo "   d. Select events: transfer.paid, transfer.failed, transfer.reversed, account.updated"
echo "   e. Copy the 'Signing secret' (starts with whsec_)"
echo "   f. Add to .env: STRIPE_WEBHOOK_SECRET=\"whsec_...\""
echo "   g. Restart the service"
echo ""
echo "4. Test the service:"
echo "   curl http://localhost:8888/health"
echo ""
echo "🔒 Security Notes:"
echo "   - Your Stripe key is stored in .env (not committed to git)"
echo "   - CRON_SECRET is used to authenticate scheduled payout jobs"
echo "   - Never share these secrets or commit them to version control"
echo ""
echo "📚 Documentation:"
echo "   - API Reference: ./API_REFERENCE.md"
echo "   - Deployment Guide: ../../CREATOR_MONETIZATION_DEPLOYMENT.md"
echo ""
