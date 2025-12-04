#!/bin/bash
# 🔥 DEPLOY REAL ML AGENTS TO CLOUD RUN
# Uses Cloud Build (no local Docker required!)

set -e

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT_ID:-mychannel-prod}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-ml-agents}"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
MEMORY="${MEMORY:-8Gi}"
CPU="${CPU:-4}"
MIN_INSTANCES="${MIN_INSTANCES:-1}"
MAX_INSTANCES="${MAX_INSTANCES:-20}"
CONCURRENCY="${CONCURRENCY:-80}"
TIMEOUT="${TIMEOUT:-300}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔥🔥🔥 ML AGENTS DEPLOYMENT 🔥🔥🔥${NC}"
echo "================================================"
echo "Project: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"
echo "Memory: ${MEMORY}"
echo "CPU: ${CPU}"
echo "Min Instances: ${MIN_INSTANCES}"
echo "Max Instances: ${MAX_INSTANCES}"
echo "================================================"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI not found. Please install it first.${NC}"
    echo "   Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Authenticate with GCP (if needed)
echo -e "\n${YELLOW}🔐 Checking GCP authentication...${NC}"
if ! gcloud auth print-identity-token &> /dev/null 2>&1; then
    echo "Please authenticate with GCP:"
    gcloud auth login
fi

# Set project
echo -e "\n${YELLOW}📁 Setting project to ${PROJECT_ID}...${NC}"
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo -e "\n${YELLOW}🔧 Enabling required APIs...${NC}"
gcloud services enable cloudbuild.googleapis.com run.googleapis.com containerregistry.googleapis.com --quiet 2>/dev/null || true

# Build using Cloud Build (no local Docker needed!)
echo -e "\n${YELLOW}🔨 Building with Cloud Build (this may take 5-10 minutes)...${NC}"
gcloud builds submit \
    --tag ${IMAGE_NAME}:latest \
    --timeout=1800 \
    .

# Deploy to Cloud Run
echo -e "\n${YELLOW}🚀 Deploying to Cloud Run...${NC}"
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME}:latest \
    --platform managed \
    --region ${REGION} \
    --memory ${MEMORY} \
    --cpu ${CPU} \
    --min-instances ${MIN_INSTANCES} \
    --max-instances ${MAX_INSTANCES} \
    --timeout ${TIMEOUT} \
    --concurrency ${CONCURRENCY} \
    --set-env-vars "MODEL_DIR=/app/trained_models,ENV=production,NO_TORCH=1" \
    --allow-unauthenticated \
    --cpu-boost \
    --execution-environment gen2

# Get service URL
echo -e "\n${GREEN}✅ Deployment complete!${NC}"
echo "================================================"
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} --platform managed --region ${REGION} --format 'value(status.url)')
echo -e "🌐 Service URL: ${GREEN}${SERVICE_URL}${NC}"
echo ""
echo "📊 Available endpoints:"
echo "  - GET  ${SERVICE_URL}/health"
echo "  - GET  ${SERVICE_URL}/models"
echo "  - GET  ${SERVICE_URL}/docs"
echo "  - POST ${SERVICE_URL}/predict/viral"
echo "  - POST ${SERVICE_URL}/predict/churn"
echo "  - POST ${SERVICE_URL}/predict/fraud"
echo "  - POST ${SERVICE_URL}/predict/recommendations"
echo "  - POST ${SERVICE_URL}/predict/watch-time"
echo "  - POST ${SERVICE_URL}/predict/content-moderation"
echo "  - POST ${SERVICE_URL}/predict/sentiment"
echo "  - POST ${SERVICE_URL}/predict/dynamic-pricing"
echo "  - POST ${SERVICE_URL}/predict/lifetime-value"
echo "  - POST ${SERVICE_URL}/predict/retention"
echo "  - POST ${SERVICE_URL}/predict/engagement"
echo "  - POST ${SERVICE_URL}/predict/ad-revenue"
echo "  - POST ${SERVICE_URL}/predict/creator-success"
echo "  - POST ${SERVICE_URL}/predict/trend"
echo "  - POST ${SERVICE_URL}/predict/notification"
echo ""
echo "🔧 To test the API:"
echo "  curl ${SERVICE_URL}/health"
echo ""
echo "📖 API Documentation:"
echo "  ${SERVICE_URL}/docs"
echo "================================================"
