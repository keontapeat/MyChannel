#!/bin/bash
# Submit all 25 Vertex AI Custom Training Jobs
PROJECT="mychannel-ca26d"
REGION="us-central1"
BUCKET="gs://mychannel-ml-data"
IMAGE="gcr.io/mychannel-ca26d/vertex-trainer:latest"

submit() {
    local NAME=$1
    local MODULE=$2
    local MACHINE=${3:-"n1-standard-4"}
    echo "  → Submitting: ${NAME}"
    gcloud ai custom-jobs create \
        --project="${PROJECT}" \
        --region="${REGION}" \
        --display-name="train-${NAME}" \
        --worker-pool-spec="machine-type=${MACHINE},replica-count=1,container-image-uri=${IMAGE}" \
        --args="--model_name=${NAME}" \
        --env-vars="AIP_MODEL_DIR=${BUCKET}/models/${NAME}/,GOOGLE_CLOUD_PROJECT=${PROJECT}" \
        --command="python3,-m" \
        --format="value(name)" 2>&1 | tail -1
}

# Use gcloud ai custom-jobs create with python module spec
submit_module() {
    local NAME=$1
    local MODULE=$2
    local MACHINE=${3:-"n1-standard-4"}
    echo "  → Submitting: ${NAME} (${MODULE})"
    gcloud ai custom-jobs create \
        --project="${PROJECT}" \
        --region="${REGION}" \
        --display-name="train-${NAME}" \
        --worker-pool-spec="machine-type=${MACHINE},replica-count=1,container-image-uri=${IMAGE},python-module=${MODULE}" \
        --env-vars="AIP_MODEL_DIR=${BUCKET}/models/${NAME}/,GOOGLE_CLOUD_PROJECT=${PROJECT}" \
        --format="value(name)" 2>&1 | tail -2
}

echo "========================================="
echo " Submitting all 25 Vertex AI training jobs"
echo "========================================="

submit_module "feed-personalization"   "feed_personalization.trainer"   "n1-highmem-4"
submit_module "churn-predictor"        "churn_predictor.trainer"        "n1-standard-4"
submit_module "viral-prediction"       "viral_prediction.trainer"       "n1-highmem-4"
submit_module "fraud-detection"        "fraud_detection.trainer"        "n1-highmem-4"
submit_module "rtb-bidding"            "rtb_bidding.trainer"            "n1-highmem-4"
submit_module "search-ranking"         "search_ranking.trainer"         "n1-highmem-4"
submit_module "subscription-pricing"   "subscription_pricing.trainer"   "n1-standard-4"
submit_module "engagement-predictor"   "engagement_predictor.trainer"   "n1-standard-4"
submit_module "content-moderation"     "content_moderation.trainer"     "n1-highmem-4"
submit_module "brand-safety"           "brand_safety.trainer"           "n1-standard-4"
submit_module "lifetime-value"         "lifetime_value.trainer"         "n1-highmem-4"
submit_module "advanced-targeting"     "advanced_targeting.trainer"     "n1-highmem-4"
submit_module "notification-optimizer" "notification_optimizer.trainer" "n1-standard-4"
submit_module "watch-time-predictor"   "watch_time_predictor.trainer"   "n1-highmem-4"
submit_module "trending-ml"            "watch_time_predictor.trainer"   "n1-standard-4"
submit_module "spam-detection"         "content_moderation.trainer"     "n1-standard-4"
submit_module "recommendations"        "feed_personalization.trainer"   "n1-highmem-4"
submit_module "sentiment-analysis"     "content_moderation.trainer"     "n1-standard-4"
submit_module "ad-quality-scorer"      "brand_safety.trainer"           "n1-standard-4"
submit_module "creator-studio-ml"      "engagement_predictor.trainer"   "n1-standard-4"
submit_module "profile-view-ml"        "churn_predictor.trainer"        "n1-standard-4"
submit_module "thumbnail-generator"    "engagement_predictor.trainer"   "n1-standard-4"
submit_module "top-rank-ml"            "viral_prediction.trainer"       "n1-highmem-4"
submit_module "ad-network-ml"          "rtb_bidding.trainer"            "n1-highmem-4"
submit_module "three-strike-review"    "content_moderation.trainer"     "n1-standard-4"

echo ""
echo "[✓] All jobs submitted!"
echo "    Monitor: https://console.cloud.google.com/vertex-ai/training/custom-jobs?project=${PROJECT}"
