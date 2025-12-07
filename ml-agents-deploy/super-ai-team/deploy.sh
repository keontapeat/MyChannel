#!/bin/bash

# =============================================================================
# 🔥🤖 SUPER AI TEAM - DEPLOYMENT SCRIPT 🤖🔥
# =============================================================================
# Deploys the elite Claude Opus 4.5 ML agent team to Google Cloud Functions
# =============================================================================

set -e

echo "🔥🤖 SUPER AI TEAM DEPLOYMENT 🤖🔥"
echo "=============================================="
echo "Deploying elite AI agents to Google Cloud..."
echo "=============================================="

# Configuration
PROJECT_ID="mychannel-ca26d"
REGION="us-central1"  # Function region (Opus calls go to us-east5)
FUNCTION_NAME="super-ai-team"
RUNTIME="python311"
MEMORY="1024MB"
TIMEOUT="300s"
MIN_INSTANCES=1
MAX_INSTANCES=10

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📦 Project: ${PROJECT_ID}${NC}"
echo -e "${BLUE}🌍 Region: ${REGION}${NC}"
echo -e "${BLUE}🤖 Function: ${FUNCTION_NAME}${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Set project
echo -e "${YELLOW}📌 Setting project...${NC}"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${YELLOW}🔧 Enabling required APIs...${NC}"
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable aiplatform.googleapis.com
gcloud services enable run.googleapis.com

# Deploy the function
echo -e "${YELLOW}🚀 Deploying Super AI Team...${NC}"
echo ""

gcloud functions deploy $FUNCTION_NAME \
    --gen2 \
    --runtime=$RUNTIME \
    --region=$REGION \
    --source=. \
    --entry-point=super_ai_team_endpoint \
    --trigger-http \
    --allow-unauthenticated \
    --memory=$MEMORY \
    --timeout=$TIMEOUT \
    --min-instances=$MIN_INSTANCES \
    --max-instances=$MAX_INSTANCES \
    --set-env-vars="PROJECT_ID=$PROJECT_ID,REGION=us-east5" \
    --service-account="${PROJECT_ID}@appspot.gserviceaccount.com"

# Get the function URL
FUNCTION_URL=$(gcloud functions describe $FUNCTION_NAME --region=$REGION --format='value(serviceConfig.uri)')

echo ""
echo "=============================================="
echo -e "${GREEN}✅ SUPER AI TEAM DEPLOYED SUCCESSFULLY!${NC}"
echo "=============================================="
echo ""
echo -e "${GREEN}🔥 Function URL: ${FUNCTION_URL}${NC}"
echo ""
echo "📡 API Endpoints:"
echo "   GET  $FUNCTION_URL              - Team status"
echo "   POST $FUNCTION_URL/activate     - Activate team"
echo "   POST $FUNCTION_URL/deactivate   - Deactivate team"
echo "   POST $FUNCTION_URL/analyze/performance - Performance analysis"
echo "   POST $FUNCTION_URL/analyze/quality     - Code quality check"
echo "   POST $FUNCTION_URL/analyze/memory      - Memory optimization"
echo "   POST $FUNCTION_URL/analyze/network     - Network optimization"
echo "   POST $FUNCTION_URL/analyze/ui          - UI performance"
echo "   POST $FUNCTION_URL/analyze/full        - Full analysis (all agents)"
echo "   POST $FUNCTION_URL/debug               - Auto-debug error"
echo "   POST $FUNCTION_URL/learn               - Learn from commit"
echo "   POST $FUNCTION_URL/webhook/github      - GitHub webhook"
echo ""
echo "🧪 Test the deployment:"
echo "   curl $FUNCTION_URL"
echo ""
echo "🔗 GitHub Webhook URL (add to repo settings):"
echo "   $FUNCTION_URL/webhook/github"
echo ""
echo "=============================================="
echo -e "${GREEN}🔥🤖 SUPER AI TEAM IS NOW LIVE! 🤖🔥${NC}"
echo "=============================================="








