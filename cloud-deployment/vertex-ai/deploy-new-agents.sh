#!/bin/bash

# Deploy 5 New Vertex AI ML Agents to Cloud Run
# churn-predictor, feed-personalization, search-ranking, notification-optimizer, subscription-pricing

set -e

PROJECT_ID="mychannel-ca26d"
REGION="us-central1"

echo "Deploying 5 new Vertex AI ML agents..."
echo "Project: $PROJECT_ID | Region: $REGION"

deploy_service() {
  local NAME=$1
  local DIR=$2
  local MEMORY=$3
  local CPU=$4
  local TIMEOUT=$5

  echo ""
  echo ">>> Deploying $NAME..."
  gcloud run deploy "$NAME" \
    --source="$DIR" \
    --platform=managed \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --allow-unauthenticated \
    --memory="$MEMORY" \
    --cpu="$CPU" \
    --timeout="${TIMEOUT}s" \
    --max-instances=10 \
    --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=$REGION"
  echo ">>> $NAME deployed"
}

deploy_service "churn-predictor" \
  "./churn-predictor-service" "2Gi" "1" "10"

deploy_service "feed-personalization" \
  "./feed-personalization-service" "2Gi" "2" "10"

deploy_service "search-ranking" \
  "./search-ranking-service" "2Gi" "2" "10"

deploy_service "notification-optimizer" \
  "./notification-optimizer-service" "2Gi" "1" "10"

deploy_service "subscription-pricing" \
  "./subscription-pricing-service" "2Gi" "1" "10"

echo ""
echo "========================================"
echo "All 5 agents deployed successfully!"
echo "========================================"
echo ""
echo "Service URLs:"
for SVC in churn-predictor feed-personalization search-ranking notification-optimizer subscription-pricing; do
  URL=$(gcloud run services describe "$SVC" --region="$REGION" --project="$PROJECT_ID" --format='value(status.url)' 2>/dev/null)
  echo "  $SVC: $URL"
done
