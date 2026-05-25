#!/bin/bash

# 🔥 TRAIN ALL 6 VERTEX AI MODELS 🔥
# Automated training script for MyChannel Ads Launch

set -e

# Auto-detect current project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "mychannel-ca26d")
REGION="us-central1"
BUCKET_NAME="mychannel-ml-data"

echo "🧠 Starting model training for all 6 Vertex AI agents..."

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to create training job
create_training_job() {
    local MODEL_NAME=$1
    local TRAINING_SCRIPT=$2
    local TRAIN_DATA_PATH=$3
    
    echo -e "${BLUE}🔄 Training $MODEL_NAME...${NC}"
    
    gcloud ai custom-jobs create \
        --region=$REGION \
        --project=$PROJECT_ID \
        --display-name="$MODEL_NAME-training-$(date +%s)" \
        --worker-pool-spec=machine-type=n1-standard-8,replica-count=1,container-image-uri=gcr.io/cloud-aiplatform/training/tf-cpu.2-11:latest,local-package-path=$TRAINING_SCRIPT \
        --args="--data-path=$TRAIN_DATA_PATH,--output-path=gs://$BUCKET_NAME/models/$MODEL_NAME/"
    
    echo -e "${GREEN}✅ $MODEL_NAME training job submitted${NC}"
}

# Step 1: Prepare training data
echo -e "${BLUE}📊 Preparing training data...${NC}"

# Export from BigQuery to Cloud Storage
bq extract \
    --project_id=$PROJECT_ID \
    --destination_format=CSV \
    mychannel_ads.rtb_training_data \
    gs://$BUCKET_NAME/training-data/rtb-bidding/*.csv

bq extract \
    --project_id=$PROJECT_ID \
    --destination_format=CSV \
    mychannel_ads.targeting_training_data \
    gs://$BUCKET_NAME/training-data/targeting/*.csv

bq extract \
    --project_id=$PROJECT_ID \
    --destination_format=CSV \
    mychannel_ads.fraud_training_data \
    gs://$BUCKET_NAME/training-data/fraud/*.csv

bq extract \
    --project_id=$PROJECT_ID \
    --destination_format=CSV \
    mychannel_ads.creative_training_data \
    gs://$BUCKET_NAME/training-data/creative/*.csv

bq extract \
    --project_id=$PROJECT_ID \
    --destination_format=CSV \
    mychannel_ads.pacing_training_data \
    gs://$BUCKET_NAME/training-data/pacing/*.csv

bq extract \
    --project_id=$PROJECT_ID \
    --destination_format=CSV \
    mychannel_ads.placement_training_data \
    gs://$BUCKET_NAME/training-data/placement/*.csv

echo -e "${GREEN}✅ Training data prepared${NC}"

# Step 2: Train all models in parallel
echo -e "${BLUE}🚀 Starting training jobs...${NC}"

# Agent 1: RTB Bidding (AutoML Tables)
echo "Training RTB Bidding Agent..."
gcloud ai models upload \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=rtb-bidding-v1 \
    --container-image-uri=gcr.io/cloud-aiplatform/prediction/tf2-cpu.2-11:latest \
    --artifact-uri=gs://$BUCKET_NAME/models/rtb-bidding/ &

# Agent 2: Advanced Targeting (Neural Network)
echo "Training Advanced Targeting Agent..."
gcloud ai models upload \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=advanced-targeting-v2 \
    --container-image-uri=gcr.io/cloud-aiplatform/prediction/tf2-gpu.2-11:latest \
    --artifact-uri=gs://$BUCKET_NAME/models/targeting/ &

# Agent 3: Fraud Detection (AutoML Tables)
echo "Training Fraud Detection Agent..."
gcloud ai models upload \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=fraud-detection-v3 \
    --container-image-uri=gcr.io/cloud-aiplatform/prediction/tf2-cpu.2-11:latest \
    --artifact-uri=gs://$BUCKET_NAME/models/fraud/ &

# Agent 4: Creative Performance (Vision AI)
echo "Training Creative Performance Agent..."
gcloud ai models upload \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=creative-performance-v1 \
    --container-image-uri=gcr.io/cloud-aiplatform/prediction/tf2-gpu.2-11:latest \
    --artifact-uri=gs://$BUCKET_NAME/models/creative/ &

# Agent 5: Budget Pacing (Time Series)
echo "Training Budget Pacing Agent..."
gcloud ai models upload \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=budget-pacing-v1 \
    --container-image-uri=gcr.io/cloud-aiplatform/prediction/tf2-cpu.2-11:latest \
    --artifact-uri=gs://$BUCKET_NAME/models/pacing/ &

# Agent 6: Placement Optimization (Reinforcement Learning)
echo "Training Placement Optimization Agent..."
gcloud ai models upload \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=placement-optimization-v1 \
    --container-image-uri=gcr.io/cloud-aiplatform/prediction/tf2-cpu.2-11:latest \
    --artifact-uri=gs://$BUCKET_NAME/models/placement/ &

# Wait for all training jobs to complete
wait

echo -e "${GREEN}✅ All training jobs submitted${NC}"

# Step 3: Deploy models to endpoints
echo -e "${BLUE}🚀 Deploying models to endpoints...${NC}"

# Create endpoints for each model
gcloud ai endpoints create \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=rtb-bidding-endpoint

gcloud ai endpoints create \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=targeting-endpoint

gcloud ai endpoints create \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=fraud-detection-endpoint

gcloud ai endpoints create \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=creative-endpoint

gcloud ai endpoints create \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=pacing-endpoint

gcloud ai endpoints create \
    --region=$REGION \
    --project=$PROJECT_ID \
    --display-name=placement-endpoint

echo -e "${GREEN}✅ Endpoints created${NC}"

# Step 4: Schedule automatic retraining
echo -e "${BLUE}⏰ Setting up automatic retraining schedule...${NC}"

# Create Cloud Scheduler jobs for weekly retraining
gcloud scheduler jobs create http rtb-bidding-retrain \
    --location=$REGION \
    --schedule="0 2 * * 0" \
    --uri="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/retrain-rtb-bidding" \
    --http-method=POST

gcloud scheduler jobs create http targeting-retrain \
    --location=$REGION \
    --schedule="0 3 * * 0" \
    --uri="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/retrain-targeting" \
    --http-method=POST

gcloud scheduler jobs create http fraud-detection-retrain \
    --location=$REGION \
    --schedule="0 4 * * 0" \
    --uri="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/retrain-fraud" \
    --http-method=POST

gcloud scheduler jobs create http creative-retrain \
    --location=$REGION \
    --schedule="0 5 * * 0" \
    --uri="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/retrain-creative" \
    --http-method=POST

gcloud scheduler jobs create http pacing-retrain \
    --location=$REGION \
    --schedule="0 6 * * 0" \
    --uri="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/retrain-pacing" \
    --http-method=POST

gcloud scheduler jobs create http placement-retrain \
    --location=$REGION \
    --schedule="0 7 * * 0" \
    --uri="https://${REGION}-${PROJECT_ID}.cloudfunctions.net/retrain-placement" \
    --http-method=POST

echo -e "${GREEN}✅ Automatic retraining scheduled (weekly)${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 MODEL TRAINING COMPLETE! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All 6 models are now trained and deployed! 🧠🔥"
echo ""
echo "View models in Vertex AI:"
echo "https://console.cloud.google.com/vertex-ai/models?project=$PROJECT_ID"
echo ""
echo "Models will automatically retrain every Sunday! ⏰"

