#!/bin/bash
# Deploy CyberSecurity AI Agent to Cloud Run
set -e

PROJECT_ID="mychannel-ca26d"
REGION="us-central1"
SERVICE_NAME="cybersecurity-ai"
IMAGE="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest"

echo "🔒 Building CyberSecurity AI Agent..."
gcloud builds submit \
  --project="${PROJECT_ID}" \
  --tag="${IMAGE}" \
  .

echo "🚀 Deploying to Cloud Run..."
gcloud run deploy "${SERVICE_NAME}" \
  --project="${PROJECT_ID}" \
  --image="${IMAGE}" \
  --region="${REGION}" \
  --platform=managed \
  --no-allow-unauthenticated \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=10 \
  --timeout=60 \
  --concurrency=80 \
  --set-env-vars="PROJECT_ID=${PROJECT_ID},REGION=${REGION}" \
  --service-account="firebase-adminsdk-fbsvc@${PROJECT_ID}.iam.gserviceaccount.com"

echo ""
echo "✅ CyberSecurity AI deployed!"
echo "   URL: https://${SERVICE_NAME}-fkri6ifojq-uc.a.run.app"
echo "   Health: https://${SERVICE_NAME}-fkri6ifojq-uc.a.run.app/health"
echo ""
echo "🔑 IMPORTANT: Service is private (--no-allow-unauthenticated)"
echo "   Only Firebase Functions (agentProxy/securityGuard) can call it."
