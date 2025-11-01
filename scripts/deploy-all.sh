#!/usr/bin/env bash
set -euo pipefail

echo "==> Deploying Firebase (rules, indexes, functions)"
firebase deploy --only firestore:rules,storage:rules,firestore:indexes,functions --non-interactive || true

echo "==> Terraform init/plan/apply"
pushd infra/terraform >/dev/null
terraform init -input=false
terraform plan -input=false -out=tfplan \
  -var "project_id=${GCP_PROJECT_ID}" \
  -var "region=${GCP_REGION:-us-central1}" \
  -var "media_bucket_name=${MEDIA_BUCKET}" \
  -var "ingest_bucket_name=${INGEST_BUCKET}" \
  -var "public_bucket_name=${PUBLIC_BUCKET}"
terraform apply -auto-approve tfplan || true
popd >/dev/null

echo "==> Done"




