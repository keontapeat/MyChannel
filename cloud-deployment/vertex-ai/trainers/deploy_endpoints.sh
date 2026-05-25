#!/bin/bash
# ============================================================
# MyChannel — Deploy ALL trained models to Vertex AI Endpoints
# Run this after train_all_models.sh jobs complete
# ============================================================
set -e

PROJECT="mychannel-ca26d"
REGION="us-central1"
BUCKET="gs://mychannel-ml-data"
MACHINE_TYPE="n1-standard-2"
MIN_NODES=1
MAX_NODES=5

echo "================================================"
echo " MyChannel — Deploy All Models to Endpoints"
echo "================================================"

MODELS=(
  "feed-personalization"
  "churn-predictor"
  "viral-prediction"
  "fraud-detection"
  "rtb-bidding"
  "search-ranking"
  "subscription-pricing"
  "engagement-predictor"
  "content-moderation"
  "brand-safety"
  "lifetime-value"
  "advanced-targeting"
  "notification-optimizer"
  "watch-time-predictor"
  "trending-ml"
  "spam-detection"
  "recommendations"
  "sentiment-analysis"
  "ad-quality-scorer"
  "creator-studio-ml"
  "profile-view-ml"
  "thumbnail-generator"
  "top-rank-ml"
  "ad-network-ml"
  "three-strike-review"
)

deploy_model() {
    local MODEL_NAME=$1
    local MODEL_DIR="${BUCKET}/models/${MODEL_NAME}/"

    echo ""
    echo "  → Deploying: ${MODEL_NAME}"

    # Upload model artifact to Vertex AI Model Registry
    MODEL_ID=$(gcloud ai models upload \
        --project="${PROJECT}" \
        --region="${REGION}" \
        --display-name="${MODEL_NAME}-v2" \
        --artifact-uri="${MODEL_DIR}" \
        --container-image-uri="us-docker.pkg.dev/vertex-ai/prediction/sklearn-cpu.1-3:latest" \
        --format="value(model)" 2>/dev/null) || {
        echo "  [!] Model upload failed for ${MODEL_NAME}, skipping..."
        return
    }

    echo "  [✓] Model registered: ${MODEL_ID}"

    # Create endpoint
    ENDPOINT_ID=$(gcloud ai endpoints create \
        --project="${PROJECT}" \
        --region="${REGION}" \
        --display-name="${MODEL_NAME}-endpoint" \
        --format="value(name)" 2>/dev/null | awk -F'/' '{print $NF}') || {
        echo "  [!] Endpoint create failed for ${MODEL_NAME}, skipping..."
        return
    }

    echo "  [✓] Endpoint created: ${ENDPOINT_ID}"

    # Deploy model to endpoint
    gcloud ai endpoints deploy-model "${ENDPOINT_ID}" \
        --project="${PROJECT}" \
        --region="${REGION}" \
        --model="${MODEL_ID}" \
        --display-name="${MODEL_NAME}-deployed" \
        --machine-type="${MACHINE_TYPE}" \
        --min-replica-count="${MIN_NODES}" \
        --max-replica-count="${MAX_NODES}" \
        --traffic-split="0=100" 2>/dev/null || {
        echo "  [!] Deploy failed for ${MODEL_NAME}"
        return
    }

    echo "  [✓] LIVE: ${MODEL_NAME} → endpoint ${ENDPOINT_ID}"
    echo "      URL: https://${REGION}-aiplatform.googleapis.com/v1/projects/${PROJECT}/locations/${REGION}/endpoints/${ENDPOINT_ID}:predict"
}

for MODEL in "${MODELS[@]}"; do
    deploy_model "${MODEL}"
done

echo ""
echo "================================================"
echo " All models deployed to Vertex AI endpoints!"
echo " View at: https://console.cloud.google.com/vertex-ai/endpoints?project=${PROJECT}"
echo "================================================"
