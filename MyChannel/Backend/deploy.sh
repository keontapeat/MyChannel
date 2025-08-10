#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-central1}"
SERVICE="mychannel-ai"
REPO="app-repo"

if [[ -z "$PROJECT_ID" ]]; then
  echo "Set PROJECT_ID env var"; exit 1
fi

gcloud config set project "$PROJECT_ID" >/dev/null
gcloud services enable run.googleapis.com aiplatform.googleapis.com artifactregistry.googleapis.com \
  pubsub.googleapis.com bigquery.googleapis.com secretmanager.googleapis.com cloudbuild.googleapis.com \
  logging.googleapis.com monitoring.googleapis.com >/dev/null

# Artifact Registry
gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1 || \
gcloud artifacts repositories create "$REPO" --repository-format=docker --location="$REGION" --description="MyChannel services"

# Service account
SA_EMAIL="run-svc@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts describe "$SA_EMAIL" >/dev/null 2>&1 || \
gcloud iam service-accounts create run-svc --display-name="Cloud Run SA"

for ROLE in roles/run.invoker roles/aiplatform.user roles/secretmanager.secretAccessor roles/logging.logWriter roles/monitoring.metricWriter; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" --member="serviceAccount:${SA_EMAIL}" --role="$ROLE" >/dev/null
done

# Pub/Sub topic
gcloud pubsub topics describe events >/dev/null 2>&1 || gcloud pubsub topics create events

IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/${SERVICE}"
gcloud builds submit --tag "$IMAGE" .

gcloud run deploy "$SERVICE" --image "$IMAGE" --region "$REGION" --allow-unauthenticated \
  --service-account "$SA_EMAIL" --set-env-vars LOCATION="$REGION",GOOGLE_CLOUD_PROJECT="$PROJECT_ID"

URL=$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')
echo "Deployed $SERVICE at: $URL"


