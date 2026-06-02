#!/bin/bash
set -e

echo "🚀 Starting MyChannel Pay API..."
echo ""

# Check required environment variables
if [ -z "$DATABASE_URL" ]; then
  echo "❌ ERROR: DATABASE_URL not set"
  echo "   Example: export DATABASE_URL='postgresql://user:pass@host:5432/mychannel'"
  exit 1
fi

if [ -z "$STRIPE_SECRET" ]; then
  echo "⚠️  WARNING: STRIPE_SECRET not set (using test mode)"
  export STRIPE_SECRET="sk_test_123"
fi

if [ -z "$APP_BASE_URL" ]; then
  echo "⚠️  WARNING: APP_BASE_URL not set (using default)"
  export APP_BASE_URL="https://mychannel.live"
fi

if [ -z "$STRIPE_WEBHOOK_SECRET" ]; then
  echo "⚠️  WARNING: STRIPE_WEBHOOK_SECRET not set (webhook verification disabled)"
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
  echo "📦 Installing dependencies..."
  npm install
  echo ""
fi

# Run migration
echo "🗄️  Running database migration..."
node src/migrate.js
echo ""

# Start the service
echo "✅ Starting service on port ${PORT:-8888}..."
echo ""
npm start
