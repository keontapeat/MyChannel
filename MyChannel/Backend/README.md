MyChannel Backend (Cloud Run + Vertex AI)

This backend provides AI endpoints (e.g., summarize) using Google Vertex AI and runs on Cloud Run.

Structure
- main.py: FastAPI app with /ai/summarize
- requirements.txt: Python dependencies
- Dockerfile: Container build
- deploy.sh: Build and deploy to Cloud Run

Quick start
1. Set env vars:
   export PROJECT_ID=YOUR_PROJECT
   export REGION=us-central1
2. Enable services and deploy:
   ./deploy.sh


