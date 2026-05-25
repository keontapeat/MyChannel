#!/bin/bash
# Deploy quota-failed services to us-east1 (separate quota pool)

set -e
PROJECT_ID="mychannel-ca26d"
REGION="us-east1"
BASE="/Users/keonta/Documents/MyChannel/cloud-deployment/vertex-ai"

deploy() {
  local NAME=$1
  local DIR=$2
  echo ""
  echo ">>> Deploying $NAME to $REGION..."
  gcloud run deploy "$NAME" \
    --source="$DIR" \
    --platform=managed \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --allow-unauthenticated \
    --memory=512Mi \
    --cpu=1 \
    --timeout=30s \
    --max-instances=3 \
    --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=us-central1" \
    --quiet && echo ">>> $NAME deployed OK" || echo ">>> $NAME FAILED"
}

echo "=================================================="
echo "Deploying quota-failed services to us-east1"
echo "=================================================="

# These all failed us-central1 due to CPU quota
deploy "gaming-esports-ml"                  "$BASE/gaming-esports-ml-service"
deploy "profile-view-ml"                    "$BASE/profile-view-ml-service"
deploy "ad-network-ml"                      "$BASE/ad-network-ml-service"
deploy "semantic-search-ml"                 "$BASE/semantic-search-ml-service"
deploy "creator-studio-ml"                  "$BASE/creator-studio-ml-service"
deploy "churn-predictor"                    "$BASE/churn-predictor-service"
deploy "subscription-pricing"               "$BASE/subscription-pricing-service"
deploy "content-moderation"                 "$BASE/content-moderation-service"
deploy "contextual-analysis-predictor"      "$BASE/contextual-analysis-service"
deploy "competitor-intelligence-predictor"  "$BASE/competitor-intelligence-service"
deploy "budget-pacing-predictor"            "$BASE/budget-pacing-service"
deploy "creative-performance-predictor"     "$BASE/creative-performance-service"
deploy "conversion-attribution-predictor"   "$BASE/conversion-attribution-service"
deploy "dynamic-creative-predictor"         "$BASE/dynamic-creative-service"
deploy "inventory-forecasting-predictor"    "$BASE/inventory-forecasting-service"
deploy "sentiment-analysis"                 "$BASE/sentiment-analysis-service"
deploy "chat-moderation"                    "$BASE/chat-moderation-service"
deploy "stream-health"                      "$BASE/stream-health-service"
deploy "thumbnail-gen-v2"                   "$BASE/thumbnail-optimizer-service"
deploy "video-recommendation-predictor"     "$BASE/video-recommendation-service"

echo ""
echo "=================================================="
echo "Final URLs (us-east1):"
echo "=================================================="
ALL="gaming-esports-ml profile-view-ml ad-network-ml semantic-search-ml creator-studio-ml churn-predictor subscription-pricing content-moderation contextual-analysis-predictor competitor-intelligence-predictor budget-pacing-predictor creative-performance-predictor conversion-attribution-predictor dynamic-creative-predictor inventory-forecasting-predictor sentiment-analysis chat-moderation stream-health thumbnail-gen-v2 video-recommendation-predictor"
for SVC in $ALL; do
  URL=$(gcloud run services describe "$SVC" --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)' 2>/dev/null || echo "not deployed")
  echo "  $SVC: $URL"
done
