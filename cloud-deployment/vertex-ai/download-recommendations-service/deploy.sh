#!/bin/bash

# Deploy Download Recommendations ML Service to Google Cloud Run
# Project: mychannel-ca26d
# Region: us-central1

set -e

PROJECT_ID="mychannel-ca26d"
SERVICE_NAME="download-recommendations"
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

echo "🚀 Deploying Download Recommendations ML Service..."

# Build the container
echo "📦 Building container image..."
gcloud builds submit --tag ${IMAGE_NAME} --project ${PROJECT_ID}

# Deploy to Cloud Run
echo "☁️  Deploying to Cloud Run..."
gcloud run deploy ${SERVICE_NAME} \
  --image ${IMAGE_NAME} \
  --platform managed \
  --region ${REGION} \
  --allow-unauthenticated \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300 \
  --concurrency 80 \
  --min-instances 0 \
  --max-instances 10 \
  --set-env-vars GCP_PROJECT=${PROJECT_ID} \
  --project ${PROJECT_ID}

echo "✅ Deployment complete!"
echo "🔗 Service URL: https://${SERVICE_NAME}-fkri6ifojq-uc.a.run.app"
