#!/bin/bash
# ============================================================
# MyChannel - Full Real Vertex AI Pipeline
# Runs all 5 steps to make every ML agent real
# ============================================================

set -e

PROJECT_ID="mychannel-ca26d"
REGION="us-central1"
BUCKET="gs://mychannel-ml-data"

echo "=================================================="
echo "MyChannel Real Vertex AI Pipeline"
echo "Project: $PROJECT_ID | Region: $REGION"
echo "=================================================="
echo ""

# Ensure we're in the right directory
cd /Users/keonta/Documents/MyChannel/cloud-deployment/vertex-ai

# ── Prerequisites ──────────────────────────────────────────
echo "Checking prerequisites..."
pip install google-cloud-aiplatform google-cloud-bigquery google-cloud-firestore --quiet
echo "Dependencies ready."
echo ""

# ── Create GCS bucket for Vertex AI staging ───────────────
echo "Setting up GCS bucket for Vertex AI..."
gsutil mb -p $PROJECT_ID -c STANDARD -l $REGION $BUCKET 2>/dev/null || echo "Bucket already exists."
echo ""

# ── Enable required APIs ───────────────────────────────────
echo "Enabling required Google Cloud APIs..."
gcloud services enable aiplatform.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable bigquery.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable firestore.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable run.googleapis.com --project=$PROJECT_ID --quiet
echo "APIs enabled."
echo ""

# ── STEP 1: Setup BigQuery ─────────────────────────────────
echo "STEP 1/5: Creating BigQuery dataset and training tables..."
python3 pipeline/01_setup_bigquery.py
echo "Step 1 complete."
echo ""

# ── STEP 2: Export Firestore data ─────────────────────────
echo "STEP 2/5: Exporting Firestore data to BigQuery..."
python3 pipeline/02_export_firestore_to_bigquery.py
echo "Step 2 complete."
echo ""

# ── STEP 3: Train Vertex AI models ────────────────────────
echo "STEP 3/5: Training real Vertex AI AutoML models..."
echo "NOTE: This step takes 1-3 hours per model (13 models total)."
echo "      Estimated total time: 3-6 hours."
echo "      Models train sequentially. Do not interrupt."
echo ""
python3 pipeline/03_train_vertex_ai_models.py
echo "Step 3 complete."
echo ""

# ── STEP 4: Wire endpoints to Cloud Run services ──────────
echo "STEP 4/5: Updating Cloud Run services with real Vertex AI endpoint IDs..."
python3 pipeline/04_update_cloud_run_services.py
echo "Step 4 complete."
echo ""

# ── STEP 5: Rebuild + redeploy all services ────────────────
echo "STEP 5/5: Rebuilding Cloud Run services with real Vertex AI code..."
python3 pipeline/05_rebuild_services_with_real_vertex.py
echo "Step 5 complete."
echo ""

# ── Verify ─────────────────────────────────────────────────
echo "=================================================="
echo "Verifying Vertex AI endpoints..."
gcloud ai endpoints list --project=$PROJECT_ID --region=$REGION \
  --format="table(displayName,name)" 2>&1

echo ""
echo "Verifying Cloud Run services..."
gcloud run services list --project=$PROJECT_ID --region=$REGION \
  --format="table(metadata.name,status.url)" 2>&1 | head -30

echo ""
echo "=================================================="
echo "PIPELINE COMPLETE!"
echo "=================================================="
echo ""
echo "All MyChannel Vertex AI ML agents are now REAL:"
echo "  - 13 trained AutoML models on Vertex AI"
echo "  - All Cloud Run services call real endpoints"
echo "  - Training data sourced from your Firestore"
echo ""
echo "Monitor training jobs:"
echo "  https://console.cloud.google.com/vertex-ai/training/training-pipelines?project=$PROJECT_ID"
echo ""
echo "Monitor endpoints:"
echo "  https://console.cloud.google.com/vertex-ai/endpoints?project=$PROJECT_ID"
