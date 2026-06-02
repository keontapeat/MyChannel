#!/usr/bin/env bash
#
# Safe redeploy of the escrow-payments function WITH the new merch endpoints.
#
# Why this script exists: the raw `npm run deploy` passes
# --set-env-vars STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY,... . If those shell vars
# are empty, the deploy BLANKS your live Stripe keys and breaks VS-match
# payments. This script reads the CURRENT keys off the already-deployed function
# first, so they are preserved no matter what.
#
# Usage:
#   gcloud auth login                       # one time (opens browser)
#   gcloud config set project mychannel-ca26d
#   bash deploy-merch.sh
#
set -euo pipefail

REGION="us-central1"
FN="escrow-payments"
PROJECT="mychannel-ca26d"

# Resolve gcloud: prefer PATH, fall back to the local SDK in the repo root.
if command -v gcloud >/dev/null 2>&1; then
  GCLOUD="gcloud"
elif [ -x "../../google-cloud-sdk/bin/gcloud" ]; then
  GCLOUD="../../google-cloud-sdk/bin/gcloud"
else
  echo "❌ gcloud not found. Install it or run from repo with ./google-cloud-sdk."
  exit 1
fi

echo "🔎 Reading existing env vars off the deployed function (keys are preserved)…"
EXISTING="$($GCLOUD functions describe "$FN" --gen2 --region="$REGION" --project="$PROJECT" \
  --format="value(serviceConfig.environmentVariables.STRIPE_SECRET_KEY)" 2>/dev/null || true)"

if [ -z "${STRIPE_SECRET_KEY:-}" ]; then
  if [ -n "$EXISTING" ]; then
    echo "✅ Reusing STRIPE_SECRET_KEY already set on the deployed function."
    STRIPE_SECRET_KEY="$EXISTING"
  else
    echo "❌ No STRIPE_SECRET_KEY in your shell AND none on the function."
    echo "   export STRIPE_SECRET_KEY=sk_live_... (or sk_test_...) and re-run."
    exit 1
  fi
fi

if [ -z "${STRIPE_WEBHOOK_SECRET:-}" ]; then
  WH="$($GCLOUD functions describe "$FN" --gen2 --region="$REGION" --project="$PROJECT" \
    --format="value(serviceConfig.environmentVariables.STRIPE_WEBHOOK_SECRET)" 2>/dev/null || true)"
  if [ -n "$WH" ]; then
    echo "✅ Reusing STRIPE_WEBHOOK_SECRET already set on the deployed function."
    STRIPE_WEBHOOK_SECRET="$WH"
  else
    echo "⚠️  No STRIPE_WEBHOOK_SECRET found. Webhook verification will fail until set."
    STRIPE_WEBHOOK_SECRET=""
  fi
fi

# Report which Stripe mode we're about to deploy with (no secrets printed).
case "$STRIPE_SECRET_KEY" in
  sk_live_*) echo "🔴 Deploying with a LIVE Stripe key — real cards will be charged." ;;
  sk_test_*) echo "🟡 Deploying with a TEST Stripe key — safe to test." ;;
  *) echo "❓ Unrecognized Stripe key prefix." ;;
esac

read -r -p "Proceed with deploy? [y/N] " ok
[ "$ok" = "y" ] || { echo "Aborted."; exit 1; }

$GCLOUD functions deploy "$FN" \
  --gen2 --runtime=nodejs20 --region="$REGION" --project="$PROJECT" \
  --source=. --entry-point=escrowPayments --trigger-http --allow-unauthenticated \
  --memory=256MB --timeout=60s \
  --set-env-vars "STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY,STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET"

echo "✅ Deployed. Merch endpoints live: /create-merch-order, /refund-merch-order"
