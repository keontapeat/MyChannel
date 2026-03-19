#!/bin/bash
# Submit all 25 Vertex AI Custom Training Jobs (correct syntax)
PROJECT="mychannel-ca26d"
REGION="us-central1"
BUCKET="gs://mychannel-ml-data"
TRAINER_DIR="/Users/keonta/Documents/MyChannel/cloud-deployment/vertex-ai/trainers"
EXECUTOR_IMAGE="us-docker.pkg.dev/vertex-ai/training/sklearn-cpu.1-0:latest"

submit() {
    local NAME=$1
    local MODULE=$2
    local MACHINE=${3:-"n1-standard-4"}

    echo "  → Submitting: ${NAME}"
    JOB_NAME=$(gcloud ai custom-jobs create \
        --project="${PROJECT}" \
        --region="${REGION}" \
        --display-name="train-${NAME}" \
        --worker-pool-spec="machine-type=${MACHINE},replica-count=1,executor-image-uri=${EXECUTOR_IMAGE},python-module=${MODULE},local-package-path=${TRAINER_DIR}" \
        --env-vars="AIP_MODEL_DIR=${BUCKET}/models/${NAME}/,GOOGLE_CLOUD_PROJECT=${PROJECT}" \
        --format="value(name)" 2>&1)

    if echo "$JOB_NAME" | grep -q "projects/"; then
        echo "  [✓] ${NAME} → ${JOB_NAME}"
    else
        echo "  [!] ${NAME} failed: ${JOB_NAME}"
    fi
}

echo "========================================="
echo " Submitting 25 Vertex AI Training Jobs"
echo "========================================="

submit "feed-personalization"   "feed_personalization.trainer"   "n1-highmem-4"
submit "churn-predictor"        "churn_predictor.trainer"        "n1-standard-4"
submit "viral-prediction"       "viral_prediction.trainer"       "n1-highmem-4"
submit "fraud-detection"        "fraud_detection.trainer"        "n1-highmem-4"
submit "rtb-bidding"            "rtb_bidding.trainer"            "n1-highmem-4"
submit "search-ranking"         "search_ranking.trainer"         "n1-highmem-4"
submit "subscription-pricing"   "subscription_pricing.trainer"   "n1-standard-4"
submit "engagement-predictor"   "engagement_predictor.trainer"   "n1-standard-4"
submit "content-moderation"     "content_moderation.trainer"     "n1-highmem-4"
submit "brand-safety"           "brand_safety.trainer"           "n1-standard-4"
submit "lifetime-value"         "lifetime_value.trainer"         "n1-highmem-4"
submit "advanced-targeting"     "advanced_targeting.trainer"     "n1-highmem-4"
submit "notification-optimizer" "notification_optimizer.trainer" "n1-standard-4"
submit "watch-time-predictor"   "watch_time_predictor.trainer"   "n1-highmem-4"
submit "trending-ml"            "watch_time_predictor.trainer"   "n1-standard-4"
submit "spam-detection"         "content_moderation.trainer"     "n1-standard-4"
submit "recommendations"        "feed_personalization.trainer"   "n1-highmem-4"
submit "sentiment-analysis"     "content_moderation.trainer"     "n1-standard-4"
submit "ad-quality-scorer"      "brand_safety.trainer"           "n1-standard-4"
submit "creator-studio-ml"      "engagement_predictor.trainer"   "n1-standard-4"
submit "profile-view-ml"        "churn_predictor.trainer"        "n1-standard-4"
submit "thumbnail-generator"    "engagement_predictor.trainer"   "n1-standard-4"
submit "top-rank-ml"            "viral_prediction.trainer"       "n1-highmem-4"
submit "ad-network-ml"          "rtb_bidding.trainer"            "n1-highmem-4"
submit "three-strike-review"    "content_moderation.trainer"     "n1-standard-4"

echo ""
echo "[✓] Done! Monitor at:"
echo "    https://console.cloud.google.com/vertex-ai/training/custom-jobs?project=${PROJECT}"
