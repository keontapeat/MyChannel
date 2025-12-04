#!/bin/bash
# =============================================================================
# 🛡️🔥 DEPLOY FILE GUARDIAN OPUS 4.5 🔥🛡️
# =============================================================================

set -e

PROJECT_ID="mychannel-ca26d"
REGION="us-central1"
FUNCTION_NAME="file-guardian-opus"

echo "🛡️🔥 DEPLOYING FILE GUARDIAN OPUS 4.5 🔥🛡️"
echo "============================================"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Function: $FUNCTION_NAME"
echo ""

# Deploy to Cloud Functions
gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=python311 \
    --region=$REGION \
    --source=. \
    --entry-point=file_guardian_opus \
    --trigger-http \
    --allow-unauthenticated \
    --memory=512MB \
    --timeout=60s \
    --set-env-vars="PROJECT_ID=$PROJECT_ID" \
    --project=$PROJECT_ID

echo ""
echo "✅ FILE GUARDIAN OPUS 4.5 DEPLOYED!"
echo ""
echo "Endpoint: https://$REGION-$PROJECT_ID.cloudfunctions.net/$FUNCTION_NAME"
echo ""
echo "Test with:"
echo "curl https://$REGION-$PROJECT_ID.cloudfunctions.net/$FUNCTION_NAME"




