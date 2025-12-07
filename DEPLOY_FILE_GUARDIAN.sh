#!/bin/bash
# =============================================================================
# 🛡️🔥 DEPLOY FILE GUARDIAN OPUS 4.5 - ONE-CLICK DEPLOYMENT 🔥🛡️
# =============================================================================
# 
# This script deploys the File Guardian Opus 4.5 ML Agent to Google Cloud.
# 
# PREREQUISITES:
# 1. Run: gcloud auth login
# 2. Run: gcloud config set project mychannel-ca26d
#
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_ID="mychannel-ca26d"
REGION="us-central1"
FUNCTION_NAME="file-guardian-opus"

echo ""
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${MAGENTA}🛡️🔥 DEPLOYING FILE GUARDIAN OPUS 4.5 🔥🛡️${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Project:${NC} $PROJECT_ID"
echo -e "${BLUE}Region:${NC} $REGION"
echo -e "${BLUE}Function:${NC} $FUNCTION_NAME"
echo -e "${BLUE}Model:${NC} Claude Opus 4.5 (claude-opus-4-5-20250514)"
echo ""

# Check if logged in
echo -e "${CYAN}Checking authentication...${NC}"
if ! gcloud auth print-access-token &>/dev/null; then
    echo -e "${RED}❌ Not authenticated. Please run:${NC}"
    echo -e "${YELLOW}   gcloud auth login${NC}"
    echo -e "${YELLOW}   gcloud config set project $PROJECT_ID${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Authenticated${NC}"

# Navigate to agent directory
cd "$(dirname "$0")/ml-agents-deploy/file-guardian-opus"

# Deploy
echo ""
echo -e "${CYAN}Deploying to Cloud Functions...${NC}"
echo ""

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

ENDPOINT="https://$REGION-$PROJECT_ID.cloudfunctions.net/$FUNCTION_NAME"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ FILE GUARDIAN OPUS 4.5 DEPLOYED!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Endpoint:${NC} $ENDPOINT"
echo ""
echo -e "${CYAN}Test the agent:${NC}"
echo -e "${YELLOW}curl $ENDPOINT${NC}"
echo ""
echo -e "${CYAN}Test file protection:${NC}"
echo -e "${YELLOW}curl -X POST $ENDPOINT \\
  -H 'Content-Type: application/json' \\
  -d '{\"operation\": \"delete\", \"file_path\": \"MyChannel/App/MyChannelApp.swift\", \"source\": \"test\"}'${NC}"
echo ""
echo -e "${MAGENTA}🛡️🔥 YOUR FILES ARE NOW PROTECTED BY OPUS 4.5! 🔥🛡️${NC}"
echo ""








