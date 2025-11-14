#!/bin/bash
# 🤖 VERTEX AI AGENT AUTOPILOT SETUP
# Run this after creating agents in Vertex AI console

set -e

PROJECT_ID="mychannel-ca26d"
PROJECT_NUMBER="124515086975"
LOCATION="us-central1"

echo "🚀 Starting Vertex AI Agent Autopilot Setup..."
echo "📋 Project: $PROJECT_ID"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check if gcloud is authenticated
echo "${BLUE}Step 1: Checking Google Cloud authentication...${NC}"
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "keontapeat@mychannel.live"; then
    echo "${YELLOW}⚠️  Need to login to Google Cloud as keontapeat@mychannel.live${NC}"
    echo "Run: gcloud auth login"
    exit 1
fi
echo "${GREEN}✅ Authenticated as keontapeat@mychannel.live${NC}"
echo ""

# Step 2: Set the project
echo "${BLUE}Step 2: Setting Google Cloud project...${NC}"
gcloud config set project $PROJECT_ID
echo "${GREEN}✅ Project set to $PROJECT_ID${NC}"
echo ""

# Step 3: Enable Vertex AI API
echo "${BLUE}Step 3: Enabling Vertex AI APIs...${NC}"
gcloud services enable aiplatform.googleapis.com --project=$PROJECT_ID
gcloud services enable compute.googleapis.com --project=$PROJECT_ID
gcloud services enable storage-api.googleapis.com --project=$PROJECT_ID
echo "${GREEN}✅ APIs enabled${NC}"
echo ""

# Step 4: List existing agents
echo "${BLUE}Step 4: Checking for existing Vertex AI agents...${NC}"
echo "Run this command in Google Cloud Console or via gcloud:"
echo ""
echo "gcloud ai agents list --location=$LOCATION --project=$PROJECT_ID"
echo ""
echo "${YELLOW}📝 MANUAL STEP REQUIRED:${NC}"
echo "1. Go to: https://console.cloud.google.com/vertex-ai/agents?project=$PROJECT_ID"
echo "2. Click 'Create Agent' for each of the 5 agents"
echo "3. Copy the prompts from QUICK_AGENT_SETUP.md"
echo "4. After creating each agent, copy its Agent ID"
echo "5. Come back here with the 5 Agent IDs"
echo ""
echo "${GREEN}✅ Setup complete! Ready for agent creation${NC}"
echo ""
echo "💰 Using your Gen App Builder credits: \$1,000 available!"
echo "🎯 Create these 5 agents first:"
echo "   1. Creator Coach Agent"
echo "   2. CPS Guardian Agent"  
echo "   3. Support Agent"
echo "   4. Super AGI Code Debugger"
echo "   5. Universe Company Agent"
echo ""
echo "🔗 Quick Link: https://console.cloud.google.com/vertex-ai/generative/agent-builder/agents?project=$PROJECT_ID"

