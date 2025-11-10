#!/bin/bash
# 🔥 BIGQUERY EXPORT SETUP SCRIPT
# Enables Firebase → BigQuery automatic data export
# This is CRITICAL for Vertex AI Agent Builder!

set -e

echo "🚀 Setting up BigQuery export for MyChannel..."

# Colors for output
RED='\033[0:31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${GOOGLE_CLOUD_PROJECT_ID:-mychannel-ca26d}"
DATASET_ID="mychannel_analytics"
LOCATION="us-central1"

echo "${YELLOW}📊 Project: $PROJECT_ID${NC}"
echo "${YELLOW}📊 Dataset: $DATASET_ID${NC}"
echo "${YELLOW}📊 Location: $LOCATION${NC}"

# Step 1: Enable BigQuery API
echo ""
echo "${GREEN}✅ Step 1: Enabling BigQuery API...${NC}"
gcloud services enable bigquery.googleapis.com --project=$PROJECT_ID

# Step 2: Create BigQuery dataset
echo ""
echo "${GREEN}✅ Step 2: Creating BigQuery dataset...${NC}"
bq --project_id=$PROJECT_ID mk --dataset --location=$LOCATION $DATASET_ID || echo "${YELLOW}Dataset already exists${NC}"

# Step 3: Create tables for Firebase exports
echo ""
echo "${GREEN}✅ Step 3: Creating BigQuery tables...${NC}"

# Videos table
bq --project_id=$PROJECT_ID mk --table ${DATASET_ID}.videos \
  id:STRING,title:STRING,description:STRING,creator_id:STRING,category:STRING,\
  view_count:INTEGER,like_count:INTEGER,comment_count:INTEGER,\
  duration:FLOAT,created_at:TIMESTAMP,updated_at:TIMESTAMP,\
  tags:STRING,thumbnail_url:STRING,video_url:STRING || echo "${YELLOW}Videos table exists${NC}"

# Views table (for tracking)
bq --project_id=$PROJECT_ID mk --table ${DATASET_ID}.video_views \
  video_id:STRING,user_id:STRING,session_id:STRING,\
  watch_duration:FLOAT,completion_rate:FLOAT,\
  timestamp:TIMESTAMP,is_self_view:BOOLEAN || echo "${YELLOW}Views table exists${NC}"

# Users table
bq --project_id=$PROJECT_ID mk --table ${DATASET_ID}.users \
  id:STRING,username:STRING,display_name:STRING,email:STRING,\
  subscriber_count:INTEGER,video_count:INTEGER,total_views:INTEGER,\
  created_at:TIMESTAMP,is_verified:BOOLEAN,is_creator:BOOLEAN || echo "${YELLOW}Users table exists${NC}"

# Likes table
bq --project_id=$PROJECT_ID mk --table ${DATASET_ID}.likes \
  user_id:STRING,video_id:STRING,\
  timestamp:TIMESTAMP || echo "${YELLOW}Likes table exists${NC}"

# Comments table
bq --project_id=$PROJECT_ID mk --table ${DATASET_ID}.comments \
  id:STRING,video_id:STRING,user_id:STRING,content:STRING,\
  like_count:INTEGER,timestamp:TIMESTAMP || echo "${YELLOW}Comments table exists${NC}"

# Subscriptions table
bq --project_id=$PROJECT_ID mk --table ${DATASET_ID}.subscriptions \
  subscriber_id:STRING,creator_id:STRING,\
  subscribed_at:TIMESTAMP || echo "${YELLOW}Subscriptions table exists${NC}"

# Ad impressions table
bq --project_id=$PROJECT_ID mk --table ${DATASET_ID}.ad_impressions \
  video_id:STRING,user_id:STRING,ad_id:STRING,\
  cpm:FLOAT,revenue:FLOAT,timestamp:TIMESTAMP || echo "${YELLOW}Ad impressions table exists${NC}"

# Step 4: Grant Firebase service account access to BigQuery
echo ""
echo "${GREEN}✅ Step 4: Granting Firebase access to BigQuery...${NC}"
FIREBASE_SA="firebase-adminsdk@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$FIREBASE_SA" \
  --role="roles/bigquery.dataEditor"

# Step 5: Create Cloud Function for Firestore → BigQuery sync
echo ""
echo "${GREEN}✅ Step 5: Setting up sync function...${NC}"

cat > /tmp/sync_to_bigquery.py << 'EOF'
from google.cloud import bigquery
from google.cloud import firestore
import functions_framework
from datetime import datetime

bq_client = bigquery.Client()
fs_client = firestore.Client()

@functions_framework.cloud_event
def sync_to_bigquery(cloud_event):
    """Sync Firestore changes to BigQuery"""
    
    # Parse Firestore event
    firestore_payload = cloud_event.data
    path_parts = firestore_payload["value"]["name"].split("/documents/")[1].split("/")
    collection = path_parts[0]
    doc_id = path_parts[1] if len(path_parts) > 1 else None
    
    # Get document data
    doc_data = firestore_payload["value"]["fields"]
    
    # Determine table based on collection
    table_map = {
        "videos": "mychannel_analytics.videos",
        "users": "mychannel_analytics.users",
        "likes": "mychannel_analytics.likes",
        "comments": "mychannel_analytics.comments",
        "subscriptions": "mychannel_analytics.subscriptions",
        "video_analytics": "mychannel_analytics.video_views"
    }
    
    table_id = table_map.get(collection)
    if not table_id:
        print(f"Collection {collection} not mapped to BigQuery table")
        return
    
    # Insert row into BigQuery
    table = bq_client.get_table(table_id)
    
    # Convert Firestore document to BigQuery row
    row = convert_firestore_to_bq(doc_data)
    row["id"] = doc_id
    row["updated_at"] = datetime.utcnow().isoformat()
    
    errors = bq_client.insert_rows_json(table, [row])
    if errors:
        print(f"BigQuery insert errors: {errors}")
    else:
        print(f"Synced {collection}/{doc_id} to BigQuery")

def convert_firestore_to_bq(fields):
    """Convert Firestore field format to BigQuery row"""
    row = {}
    for key, value in fields.items():
        # Get the actual value from Firestore format
        if "stringValue" in value:
            row[key] = value["stringValue"]
        elif "integerValue" in value:
            row[key] = int(value["integerValue"])
        elif "doubleValue" in value:
            row[key] = float(value["doubleValue"])
        elif "booleanValue" in value:
            row[key] = value["booleanValue"]
        elif "timestampValue" in value:
            row[key] = value["timestampValue"]
    return row
EOF

echo "${YELLOW}Sync function created at /tmp/sync_to_bigquery.py${NC}"
echo "${YELLOW}Deploy with: gcloud functions deploy sync_to_bigquery --runtime python311 --trigger-event providers/cloud.firestore/eventTypes/document.write${NC}"

# Step 6: Enable Firebase Analytics export
echo ""
echo "${GREEN}✅ Step 6: Enabling Firebase Analytics → BigQuery export...${NC}"
echo "${YELLOW}📝 MANUAL STEP REQUIRED:${NC}"
echo "1. Go to Firebase Console: https://console.firebase.google.com/project/${PROJECT_ID}"
echo "2. Navigate to: Settings → Integrations → BigQuery"
echo "3. Click 'Link' and select:"
echo "   - ✅ Analytics"
echo "   - ✅ Firestore"
echo "   - ✅ Cloud Storage"
echo "4. Select dataset: ${DATASET_ID}"
echo "5. Click 'Link'"

# Step 7: Verify setup
echo ""
echo "${GREEN}✅ Step 7: Verifying setup...${NC}"
bq ls --project_id=$PROJECT_ID ${DATASET_ID} || echo "${RED}Failed to list tables${NC}"

echo ""
echo "${GREEN}🎉 BigQuery export setup complete!${NC}"
echo ""
echo "${YELLOW}📝 NEXT STEPS:${NC}"
echo "1. Complete manual Firebase integration (see above)"
echo "2. Wait 24 hours for first data export"
echo "3. Verify data: bq query --project_id=${PROJECT_ID} 'SELECT COUNT(*) FROM ${DATASET_ID}.videos'"
echo "4. Build Vertex AI agents that query this data!"
echo ""
echo "${GREEN}💰 COST ESTIMATE:${NC}"
echo "- Storage: ~\$20/TB/month (you'll use < 1GB for months)"
echo "- Queries: ~\$5/TB scanned (free tier: 1TB/month)"
echo "- Your Google Cloud credits: \$350,000"
echo "- ${GREEN}Effective cost: \$0${NC} ✅"
echo ""

