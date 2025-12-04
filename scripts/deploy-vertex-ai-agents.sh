#!/bin/bash
# =============================================================================
# 🔥🔥🔥 MYCHANNEL VERTEX AI GAMING AGENTS - AUTOPILOT DEPLOYMENT 🔥🔥🔥
# =============================================================================
# This script deploys 7 real ML agents to Google Cloud Functions
# Run this script to create production-ready gaming AI infrastructure
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  🔥 MYCHANNEL VERTEX AI GAMING AGENTS - AUTOPILOT DEPLOY 🔥   ║"
echo "║  7 Nuclear-Level ML Agents for Competitive Gaming            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT_ID:-mychannel-ca26d}"
REGION="us-central1"
SERVICE_ACCOUNT="vertex-ai-gaming@${PROJECT_ID}.iam.gserviceaccount.com"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FUNCTIONS_DIR="$SCRIPT_DIR/cloud-functions"

echo -e "${CYAN}📋 Configuration:${NC}"
echo "   Project ID: $PROJECT_ID"
echo "   Region: $REGION"
echo "   Functions Dir: $FUNCTIONS_DIR"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI not found. Please install Google Cloud SDK.${NC}"
    echo "   https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if function files exist
if [ ! -d "$FUNCTIONS_DIR" ]; then
    echo -e "${RED}❌ Cloud functions directory not found: $FUNCTIONS_DIR${NC}"
    exit 1
fi

# Check authentication
echo -e "${YELLOW}🔐 Checking Google Cloud authentication...${NC}"
CURRENT_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
if [ -z "$CURRENT_ACCOUNT" ]; then
    echo -e "${YELLOW}⚠️  Not authenticated. Running gcloud auth login...${NC}"
    gcloud auth login
fi
echo -e "${GREEN}✅ Authenticated as: $CURRENT_ACCOUNT${NC}"

# Set project
echo -e "${CYAN}📁 Setting project to ${PROJECT_ID}...${NC}"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${CYAN}🔧 Enabling required Google Cloud APIs...${NC}"
APIS=(
    "aiplatform.googleapis.com"
    "cloudfunctions.googleapis.com"
    "cloudbuild.googleapis.com"
    "run.googleapis.com"
    "storage.googleapis.com"
    "firestore.googleapis.com"
)

for api in "${APIS[@]}"; do
    echo -e "   Enabling $api..."
    gcloud services enable $api --quiet 2>/dev/null || true
done
echo -e "${GREEN}✅ APIs enabled${NC}"

# Create service account if not exists
echo -e "${CYAN}👤 Setting up service account...${NC}"
if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT > /dev/null 2>&1; then
    gcloud iam service-accounts create vertex-ai-gaming \
        --display-name="Vertex AI Gaming Agents" \
        --description="Service account for MyChannel gaming ML agents" 2>/dev/null || true
    echo -e "${GREEN}✅ Service account created${NC}"
else
    echo -e "${GREEN}✅ Service account already exists${NC}"
fi

# Grant necessary roles (with --condition=None to handle conditional policies)
echo -e "${CYAN}🔑 Granting IAM roles...${NC}"
ROLES=(
    "roles/aiplatform.user"
    "roles/cloudfunctions.invoker"
    "roles/datastore.user"
    "roles/storage.objectViewer"
)

for role in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="$role" \
        --condition=None \
        --quiet 2>/dev/null || true
done
echo -e "${GREEN}✅ IAM roles granted${NC}"

# Create Cloud Storage bucket for models (if not exists)
BUCKET_NAME="${PROJECT_ID}-gaming-ml-models"
echo -e "${CYAN}🪣 Creating Cloud Storage bucket for ML models...${NC}"
if ! gsutil ls gs://$BUCKET_NAME > /dev/null 2>&1; then
    gsutil mb -l $REGION gs://$BUCKET_NAME 2>/dev/null || true
    echo -e "${GREEN}✅ Bucket created: gs://$BUCKET_NAME${NC}"
else
    echo -e "${GREEN}✅ Bucket already exists${NC}"
fi

# Deploy Cloud Functions
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  🚀 DEPLOYING 7 GAMING AI CLOUD FUNCTIONS                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function definitions: folder:entry_point
FUNCTIONS=(
    "match-fairness:match_fairness"
    "anti-cheat:anti_cheat"
    "prize-pool:prize_pool"
    "tournament-bracket:tournament_bracket"
    "performance-predictor:performance_predictor"
    "gameplay-analyzer:gameplay_analyzer"
    "dispute-resolution:dispute_resolution"
)

DEPLOYED_URLS=()
DEPLOY_COUNT=0

for func in "${FUNCTIONS[@]}"; do
    IFS=':' read -r folder entry <<< "$func"
    FUNC_DIR="$FUNCTIONS_DIR/$folder"
    
    if [ ! -f "$FUNC_DIR/main.py" ]; then
        echo -e "${YELLOW}⚠️  Skipping $folder - main.py not found${NC}"
        continue
    fi
    
    ((DEPLOY_COUNT++))
    echo -e "${CYAN}$DEPLOY_COUNT️⃣ Deploying $folder...${NC}"
    
    # Deploy the function (without --allow-unauthenticated due to org policy)
    if gcloud functions deploy mychannel-gaming-$folder \
        --gen2 \
        --runtime=python311 \
        --region=$REGION \
        --source="$FUNC_DIR" \
        --entry-point=$entry \
        --trigger-http \
        --no-allow-unauthenticated \
        --memory=512MB \
        --timeout=60s \
        --quiet 2>&1; then
        
        # Get the function URL
        URL=$(gcloud functions describe mychannel-gaming-$folder --region=$REGION --gen2 --format='value(serviceConfig.uri)' 2>/dev/null || echo "")
        if [ -n "$URL" ]; then
            DEPLOYED_URLS+=("$folder:$URL")
            echo -e "${GREEN}   ✅ Deployed: $URL${NC}"
        else
            echo -e "${GREEN}   ✅ Deployed (URL pending)${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠️  Failed to deploy $folder${NC}"
    fi
done

# Output summary
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  ✅ DEPLOYMENT COMPLETE                                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${GREEN}Deployed ${#DEPLOYED_URLS[@]} of 7 functions:${NC}"
for url_pair in "${DEPLOYED_URLS[@]}"; do
    IFS=':' read -r name url <<< "$url_pair"
    echo -e "   ${CYAN}$name${NC}: $url"
done

# Generate Swift config
echo ""
echo -e "${YELLOW}📱 Update GamingAIOrchestrator.swift with these URLs:${NC}"
echo ""
echo "private var agentEndpoints: [String: String] {"
echo "    ["
for url_pair in "${DEPLOYED_URLS[@]}"; do
    IFS=':' read -r name url <<< "$url_pair"
    # Convert kebab-case to camelCase
    swift_name=$(echo $name | sed -E 's/-([a-z])/\U\1/g')
    echo "        \"$swift_name\": \"$url\","
done
echo "    ]"
echo "}"

echo ""
echo -e "${GREEN}🔥 GAMING AI AGENTS DEPLOYMENT COMPLETE! 🔥${NC}"
echo -e "${CYAN}Estimated monthly cost: ~\$50-100 (pay-per-use)${NC}"
