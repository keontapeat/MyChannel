#!/bin/bash
# Deploy all new ML services to Cloud Run

set -e
PROJECT_ID="mychannel-ca26d"
REGION="us-central1"
BASE="/Users/keonta/Documents/MyChannel/cloud-deployment/vertex-ai"

deploy() {
  local NAME=$1
  local DIR=$2
  echo ""
  echo ">>> Deploying $NAME..."
  EXTRA_FLAGS=""
  # Check if service already exists and needs --clear-base-image
  if gcloud run services describe "$NAME" --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
    EXTRA_FLAGS="--clear-base-image"
  fi
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
    --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION" \
    --quiet \
    $EXTRA_FLAGS && echo ">>> $NAME deployed OK" || echo ">>> $NAME FAILED"
}

echo "=================================================="
echo "Deploying all new MyChannel ML services"
echo "=================================================="

# ── New ML Services ──────────────────────────────────────
deploy "watch-time-predictor"      "$BASE/watch-time-predictor-service"
deploy "top-rank-ml"               "$BASE/top-rank-ml-service"
deploy "trending-ml"               "$BASE/trending-ml-service"
deploy "three-strike-review"       "$BASE/three-strike-review-service"
deploy "gaming-esports-ml"         "$BASE/gaming-esports-ml-service"
deploy "profile-view-ml"           "$BASE/profile-view-ml-service"
deploy "ad-network-ml"             "$BASE/ad-network-ml-service"
deploy "semantic-search-ml"        "$BASE/semantic-search-ml-service"
deploy "creator-studio-ml"         "$BASE/creator-studio-ml-service"

# ── Original Core Services ────────────────────────────────
deploy "churn-predictor"           "$BASE/churn-predictor-service"
deploy "feed-personalization"      "$BASE/feed-personalization-service"
deploy "search-ranking"            "$BASE/search-ranking-service"
deploy "notification-optimizer"    "$BASE/notification-optimizer-service"
deploy "subscription-pricing"      "$BASE/subscription-pricing-service"
deploy "rtb-bidding-predictor"     "$BASE/rtb-bidding-service"
deploy "fraud-detection-predictor" "$BASE/fraud-detection-service"
deploy "content-moderation"        "$BASE/content-moderation-service"
deploy "brand-safety-ml-predictor" "$BASE/brand-safety-ml-service"
deploy "advanced-targeting-predictor" "$BASE/advanced-targeting-service"
deploy "audience-lookalike-predictor" "$BASE/audience-lookalike-service"

# ── Ad Network Services ───────────────────────────────────
deploy "ad-quality-scorer-predictor"    "$BASE/ad-quality-scorer-service"
deploy "contextual-analysis-predictor"  "$BASE/contextual-analysis-service"
deploy "competitor-intelligence-predictor" "$BASE/competitor-intelligence-service"
deploy "viewability-prediction-predictor"  "$BASE/viewability-prediction-service"
deploy "budget-pacing-predictor"        "$BASE/budget-pacing-service"
deploy "placement-optimization-predictor" "$BASE/placement-optimization-service"
deploy "creative-performance-predictor" "$BASE/creative-performance-service"
deploy "conversion-attribution-predictor" "$BASE/conversion-attribution-service"
deploy "dynamic-creative-predictor"     "$BASE/dynamic-creative-service"
deploy "inventory-forecasting-predictor" "$BASE/inventory-forecasting-service"

# ── Platform Services ─────────────────────────────────────
deploy "sentiment-analysis"        "$BASE/sentiment-analysis-service"
deploy "chat-moderation"           "$BASE/chat-moderation-service"
deploy "stream-health"             "$BASE/stream-health-service"
deploy "thumbnail-gen-v2"          "$BASE/thumbnail-optimizer-service"
deploy "video-recommendation-predictor" "$BASE/video-recommendation-service"

echo ""
echo "=================================================="
echo "All 35 services deployed. Final URLs:"
echo "=================================================="
ALL_SVCS="watch-time-predictor top-rank-ml trending-ml three-strike-review gaming-esports-ml profile-view-ml ad-network-ml semantic-search-ml creator-studio-ml churn-predictor feed-personalization search-ranking notification-optimizer subscription-pricing rtb-bidding-predictor fraud-detection-predictor content-moderation brand-safety-ml-predictor advanced-targeting-predictor audience-lookalike-predictor ad-quality-scorer-predictor contextual-analysis-predictor competitor-intelligence-predictor viewability-prediction-predictor budget-pacing-predictor placement-optimization-predictor creative-performance-predictor conversion-attribution-predictor dynamic-creative-predictor inventory-forecasting-predictor sentiment-analysis chat-moderation stream-health thumbnail-gen-v2 video-recommendation-predictor"
for SVC in $ALL_SVCS; do
  URL=$(gcloud run services describe "$SVC" --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)' 2>/dev/null || echo "not deployed")
  echo "  $SVC: $URL"
done
