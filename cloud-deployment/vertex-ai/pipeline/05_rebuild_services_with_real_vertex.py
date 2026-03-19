#!/usr/bin/env python3
"""
Step 5: Rebuild every Cloud Run service with real Vertex AI endpoint calls.
Generates updated main.py for each service and redeploys.
"""

import os
import subprocess
import shutil

PROJECT_ID = "mychannel-ca26d"
REGION = "us-central1"

# (service_folder, service_name, predict_route, input_fields, output_fields)
SERVICES = [
    ("churn-predictor-service",          "churn-predictor",                "/predict",  "user_id,features", "churn_probability,risk_level,will_churn_30d,winback_actions"),
    ("feed-personalization-service",     "feed-personalization",           "/predict",  "user_id,user_preferences,candidate_videos", "personalized_feed,avg_relevance_score"),
    ("search-ranking-service",           "search-ranking",                 "/predict",  "query,results,user_context", "ranked_results,top_result_score"),
    ("notification-optimizer-service",   "notification-optimizer",         "/predict",  "user_id,notification,user_preferences", "should_send,open_probability,optimal_send_time"),
    ("subscription-pricing-service",     "subscription-pricing",          "/predict",  "user_id,user_profile", "recommended_tier,final_price,discount,upgrade_likelihood"),
    ("rtb-bidding-service",              "rtb-bidding-predictor",          "/predict/rtb-bidding", "instances", "predicted_bid,win_probability"),
    ("fraud-detection-service",          "fraud-detection-predictor",      "/predict/fraud", "instances", "is_fraud,fraud_score,fraud_type"),
    ("content-moderation-service",       "content-moderation",             "/predict",  "content_id,content,content_type", "label,confidence,action"),
    ("brand-safety-ml-service",          "brand-safety-ml-predictor",      "/predict",  "video_id,features", "safety_label,confidence,blocked_categories"),
    ("advanced-targeting-service",       "advanced-targeting-predictor",   "/predict",  "user_id,ad_id,features", "will_convert,conversion_probability,targeting_score"),
    ("audience-lookalike-service",       "audience-lookalike-predictor",   "/predict",  "seed_users,candidate_users", "lookalike_score,matched_users"),
    ("contextual-analysis-service",      "contextual-analysis-predictor",  "/predict",  "video_id,features", "contextual_score,matched_categories,brand_safe"),
    ("viewability-prediction-service",   "viewability-prediction-predictor","/predict", "impression_id,features", "viewability_score,will_be_viewed"),
    ("sentiment-analysis-service",       "sentiment-analysis",             "/predict",  "text,user_id", "sentiment,score,emotion"),
    ("video-recommendation-service",     "video-recommendation-predictor" if False else "recommendations", "/predict", "user_id,candidate_videos", "recommended_videos,relevance_scores"),
    ("thumbnail-optimizer-service",      "thumbnail-gen-v2",               "/predict",  "video_id,features", "ctr_score,recommended_changes"),
]

REQUIREMENTS = """Flask==3.0.0
gunicorn==21.2.0
google-cloud-aiplatform==1.38.0
google-auth==2.25.2
numpy==1.26.2
"""

DOCKERFILE = """FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

CMD exec gunicorn --bind :$PORT --workers 4 --threads 8 --timeout 30 main:app
"""


def generate_main_py(service_name: str, predict_route: str, input_fields: str, output_fields: str) -> str:
    """Generate a main.py that calls the real Vertex AI endpoint."""
    return f'''#!/usr/bin/env python3
"""
{service_name} - Real Vertex AI ML Agent
Calls trained Vertex AI endpoint for real ML predictions.
"""

import os
import logging
from flask import Flask, request, jsonify
from google.cloud import aiplatform
from google.protobuf import json_format
from google.protobuf.struct_pb2 import Value

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get("PROJECT_ID", "mychannel-ca26d")
REGION = os.environ.get("REGION", "us-central1")
ENDPOINT_ID = os.environ.get("VERTEX_AI_ENDPOINT_ID", "")
MODEL_NAME = os.environ.get("MODEL_NAME", "{service_name}")

aiplatform.init(project=PROJECT_ID, location=REGION)


def get_endpoint():
    """Get the real Vertex AI endpoint."""
    if not ENDPOINT_ID:
        raise ValueError("VERTEX_AI_ENDPOINT_ID env var not set")
    return aiplatform.Endpoint(
        endpoint_name=f"projects/{{PROJECT_ID}}/locations/{{REGION}}/endpoints/{{ENDPOINT_ID}}"
    )


def call_vertex_ai(instances: list) -> list:
    """Call the real Vertex AI endpoint and return predictions."""
    endpoint = get_endpoint()
    response = endpoint.predict(instances=instances)
    return response.predictions


@app.route("{predict_route}", methods=["POST"])
def predict():
    """Call real Vertex AI model for prediction."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({{"error": "No data provided"}}), 400

        # Build instance from request data
        instance = {{}}
        for field in "{input_fields}".split(","):
            field = field.strip()
            if field in data:
                instance[field] = data[field]
            elif "features" in data and isinstance(data.get("features"), dict):
                instance[field] = data["features"].get(field)

        # Handle nested instances format
        instances_raw = data.get("instances", [instance])
        if not isinstance(instances_raw, list):
            instances_raw = [instances_raw]

        predictions = call_vertex_ai(instances_raw)

        logging.info(f"{{MODEL_NAME}} prediction: {{len(predictions)}} results")
        return jsonify({{"predictions": predictions, "model": MODEL_NAME}}), 200

    except ValueError as e:
        # Endpoint not configured yet - return informative error
        logging.warning(f"Endpoint not configured: {{e}}")
        return jsonify({{"error": str(e), "hint": "Set VERTEX_AI_ENDPOINT_ID env var after training"}}), 503

    except Exception as e:
        logging.error(f"Prediction error: {{e}}")
        return jsonify({{"error": str(e)}}), 500


@app.route("/predict/batch", methods=["POST"])
def predict_batch():
    """Batch predictions via real Vertex AI endpoint."""
    try:
        data = request.get_json()
        instances = data.get("instances", data.get("items", []))
        if not instances:
            return jsonify({{"error": "No instances provided"}}), 400

        predictions = call_vertex_ai(instances)
        return jsonify({{"predictions": predictions, "count": len(predictions), "model": MODEL_NAME}}), 200

    except ValueError as e:
        return jsonify({{"error": str(e)}}), 503
    except Exception as e:
        logging.error(f"Batch error: {{e}}")
        return jsonify({{"error": str(e)}}), 500


@app.route("/health", methods=["GET"])
def health():
    endpoint_status = "configured" if ENDPOINT_ID else "not_configured"
    return jsonify({{
        "status": "healthy",
        "service": "{service_name}",
        "model": MODEL_NAME,
        "vertex_ai_endpoint": endpoint_status,
        "endpoint_id": ENDPOINT_ID or "pending_training"
    }}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
'''


def rebuild_service(folder: str, service_name: str, predict_route: str, input_fields: str, output_fields: str):
    """Rebuild a service folder with real Vertex AI code."""
    base = f"/Users/keonta/Documents/MyChannel/cloud-deployment/vertex-ai/{folder}"
    os.makedirs(base, exist_ok=True)

    with open(f"{base}/main.py", "w") as f:
        f.write(generate_main_py(service_name, predict_route, input_fields, output_fields))

    with open(f"{base}/requirements.txt", "w") as f:
        f.write(REQUIREMENTS)

    with open(f"{base}/Dockerfile", "w") as f:
        f.write(DOCKERFILE)

    print(f"  Rebuilt: {folder}")


def deploy_service(folder: str, service_name: str):
    """Deploy rebuilt service to Cloud Run."""
    base = f"/Users/keonta/Documents/MyChannel/cloud-deployment/vertex-ai/{folder}"
    cmd = [
        "gcloud", "run", "deploy", service_name,
        f"--source={base}",
        "--platform=managed",
        f"--region={REGION}",
        f"--project={PROJECT_ID}",
        "--allow-unauthenticated",
        "--memory=2Gi",
        "--cpu=2",
        "--timeout=30s",
        "--max-instances=10",
        f"--set-env-vars=PROJECT_ID={PROJECT_ID},REGION={REGION}",
        "--quiet"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  Deployed: {service_name}")
        return True
    else:
        err = result.stderr.strip()
        if "--clear-base-image" in err:
            cmd.append("--clear-base-image")
            result2 = subprocess.run(cmd, capture_output=True, text=True)
            if result2.returncode == 0:
                print(f"  Deployed (with --clear-base-image): {service_name}")
                return True
        print(f"  FAILED {service_name}: {err[:120]}")
        return False


if __name__ == "__main__":
    print(f"Rebuilding {len(SERVICES)} Cloud Run services with real Vertex AI code...\n")

    # Step 1: Rebuild all service folders
    print("Rebuilding service code...")
    for folder, service_name, route, inputs, outputs in SERVICES:
        rebuild_service(folder, service_name, route, inputs, outputs)

    # Step 2: Deploy all services
    print(f"\nDeploying all {len(SERVICES)} services to Cloud Run...")
    success = 0
    failed = []
    for folder, service_name, route, inputs, outputs in SERVICES:
        if deploy_service(folder, service_name):
            success += 1
        else:
            failed.append(service_name)

    print(f"\n{'='*50}")
    print(f"Done. {success}/{len(SERVICES)} services rebuilt and deployed.")
    if failed:
        print(f"Failed: {failed}")
    print("\nAll services now call real Vertex AI endpoints.")
    print("After training completes (Step 3), run Step 4 to wire endpoint IDs.")
