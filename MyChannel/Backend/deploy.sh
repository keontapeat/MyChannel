#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-central1}"
SERVICE="mychannel-ai"
REPO="app-repo"

# Optional tunables
CONCURRENCY="${CONCURRENCY:-80}"
CPU="${CPU:-1}"
MEMORY="${MEMORY:-512Mi}"
MIN_INSTANCES="${MIN_INSTANCES:-0}"

# Optional config/env
API_KEY="${API_KEY:-}"
GEN_MODEL="${GEN_MODEL:-gemini-1.5-flash}"
MAX_TEXT_CHARS="${MAX_TEXT_CHARS:-4000}"

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

ENV_VARS="LOCATION=${REGION},GOOGLE_CLOUD_PROJECT=${PROJECT_ID},GEN_MODEL=${GEN_MODEL},MAX_TEXT_CHARS=${MAX_TEXT_CHARS}"
if [[ -n "$API_KEY" ]]; then
  ENV_VARS="${ENV_VARS},API_KEY=${API_KEY}"
fi

gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --region "$REGION" \
  --allow-unauthenticated \
  --service-account "$SA_EMAIL" \
  --concurrency "$CONCURRENCY" \
  --cpu "$CPU" \
  --memory "$MEMORY" \
  --min-instances "$MIN_INSTANCES" \
  --set-env-vars "$ENV_VARS"

URL=$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')
echo "Deployed $SERVICE at: $URL"