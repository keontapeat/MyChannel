#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID=${GCP_PROJECT:-""}
BUCKET=${GCS_BUCKET:-""}
REGION=${REGION:-"us-central1"}

if [[ -z "$PROJECT_ID" || -z "$BUCKET" ]]; then
  echo "Set GCP_PROJECT and GCS_BUCKET env vars" >&2
  exit 1
fi

gcloud config set project $PROJECT_ID
gsutil mb -l $REGION gs://$BUCKET || true

# Lifecycle: delete test artifacts after 90 days
cat > /tmp/lifecycle.json <<EOF
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 90}
    }
  ]
}
EOF

gsutil lifecycle set /tmp/lifecycle.json gs://$BUCKET
echo "Bucket $BUCKET ready"



