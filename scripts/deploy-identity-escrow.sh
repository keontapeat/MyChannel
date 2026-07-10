#!/usr/bin/env bash
#
# Deploy VS Match money + identity stack:
#   - create_stripe_identity_session  (Firebase Python, us-east1)
#   - stripe_identity_webhook           (Firebase Python, us-east1)
#   - escrow-payments                   (Cloud Functions gen2, us-central1)
#
# Preserves existing secrets when shell env vars are unset (same pattern as deploy-merch.sh).
#
# Usage:
#   gcloud auth login
#   gcloud config set project mychannel-ca26d
#   export STRIPE_SECRET_KEY=sk_test_...          # required if not already deployed
#   export STRIPE_IDENTITY_WEBHOOK_SECRET=whsec_... # required for Identity webhook
#   export STRIPE_WEBHOOK_SECRET=whsec_...        # required for escrow Stripe webhook
#   bash scripts/deploy-identity-escrow.sh
#
set -euo pipefail

PROJECT="${GCLOUD_PROJECT:-mychannel-ca26d}"
REGION_ESCROW="us-central1"
REGION_IDENTITY="us-east1"
FN_ESCROW="escrow-payments"

if command -v gcloud >/dev/null 2>&1; then
  GCLOUD="gcloud"
elif [ -x "./google-cloud-sdk/bin/gcloud" ]; then
  GCLOUD="./google-cloud-sdk/bin/gcloud"
else
  echo "❌ gcloud not found."
  exit 1
fi

echo "📦 Project: $PROJECT"

# --- Preserve escrow env vars ---
echo "🔎 Reading existing escrow-payments env vars…"
EXISTING_SK="$($GCLOUD functions describe "$FN_ESCROW" --gen2 --region="$REGION_ESCROW" --project="$PROJECT" \
  --format="value(serviceConfig.environmentVariables.STRIPE_SECRET_KEY)" 2>/dev/null || true)"
EXISTING_WH="$($GCLOUD functions describe "$FN_ESCROW" --gen2 --region="$REGION_ESCROW" --project="$PROJECT" \
  --format="value(serviceConfig.environmentVariables.STRIPE_WEBHOOK_SECRET)" 2>/dev/null || true)"

if [ -z "${STRIPE_SECRET_KEY:-}" ]; then
  if [ -n "$EXISTING_SK" ]; then
    echo "✅ Reusing STRIPE_SECRET_KEY from deployed escrow-payments."
    STRIPE_SECRET_KEY="$EXISTING_SK"
  else
    echo "❌ Set STRIPE_SECRET_KEY (sk_test_... or sk_live_...) and re-run."
    exit 1
  fi
fi

if [ -z "${STRIPE_WEBHOOK_SECRET:-}" ]; then
  if [ -n "$EXISTING_WH" ]; then
    echo "✅ Reusing STRIPE_WEBHOOK_SECRET from deployed escrow-payments."
    STRIPE_WEBHOOK_SECRET="$EXISTING_WH"
  else
    echo "⚠️  STRIPE_WEBHOOK_SECRET not set — escrow webhook signature verify will fail until configured."
    STRIPE_WEBHOOK_SECRET=""
  fi
fi

if [ -z "${STRIPE_IDENTITY_WEBHOOK_SECRET:-}" ]; then
  echo "⚠️  STRIPE_IDENTITY_WEBHOOK_SECRET not set — Identity webhook will return 503 until configured."
  echo "   Create a Stripe webhook endpoint for identity.verification_session.* events."
fi

if [ "${DEPLOY_CONFIRM:-}" = "y" ] || [ "${CI:-}" = "true" ]; then
  ok=y
  echo "✅ Auto-confirmed deploy (DEPLOY_CONFIRM=y or CI=true)."
else
  read -r -p "Deploy identity functions (Firebase) + escrow-payments? [y/N] " ok
fi
[ "$ok" = "y" ] || { echo "Aborted."; exit 1; }

# --- Firebase Python functions (identity) ---
echo "🆔 Deploying create_stripe_identity_session + stripe_identity_webhook (Firebase)…"
(
  cd functions
  firebase deploy --only functions:create_stripe_identity_session,functions:stripe_identity_webhook --project "$PROJECT"
)

# --- Escrow Cloud Function (Node gen2) ---
echo "💰 Deploying escrow-payments (gen2)…"
(
  cd cloud-functions/escrow-payments
  $GCLOUD functions deploy "$FN_ESCROW" \
    --gen2 --runtime=nodejs20 --region="$REGION_ESCROW" --project="$PROJECT" \
    --source=. --entry-point=escrowPayments --trigger-http --allow-unauthenticated \
    --memory=256MB --timeout=60s \
    --set-env-vars "STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY,STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET"
)

echo ""
echo "✅ Deploy complete."
echo "   Identity session: https://${REGION_IDENTITY}-${PROJECT}.cloudfunctions.net/create_stripe_identity_session"
echo "   Identity webhook: https://${REGION_IDENTITY}-${PROJECT}.cloudfunctions.net/stripe_identity_webhook"
echo "   Escrow API base:  https://${REGION_ESCROW}-${PROJECT}.cloudfunctions.net/escrow-payments"
echo ""
echo "Configure Stripe Dashboard webhooks:"
echo "  - Identity → stripe_identity_webhook (STRIPE_IDENTITY_WEBHOOK_SECRET)"
echo "  - Payments → escrow-payments/webhook (STRIPE_WEBHOOK_SECRET)"
