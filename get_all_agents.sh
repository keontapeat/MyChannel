#!/bin/bash
echo "🔥 Fetching all MyChannel Vertex AI Agents..."
gcloud conversational-agents agents list --location=us-central1 --format="table(displayName,name)" --project=mychannel-ca26d
