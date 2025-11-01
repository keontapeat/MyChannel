#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${GCP_PROJECT:-""}
REGION=${REGION:-"us-central1"}
SERVICE=${SERVICE:-"channelmind-api"}
IMAGE=gcr.io/$PROJECT_ID/$SERVICE:latest

if [[ -z "$PROJECT_ID" ]]; then
  echo "Set GCP_PROJECT env var" >&2
  exit 1
fi

gcloud config set project $PROJECT_ID
gcloud builds submit --tag $IMAGE ..

gcloud run deploy $SERVICE \
  --image $IMAGE \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --set-env-vars=DATABASE_URL=$DATABASE_URL,REDIS_URL=$REDIS_URL,API_AUTH_TOKEN=$API_AUTH_TOKEN,GCP_PROJECT=$GCP_PROJECT,GCS_BUCKET=$GCS_BUCKET,INDEX_PATH=$INDEX_PATH \
  --memory=1Gi --cpu=2

echo "Deployed $SERVICE to Cloud Run"



