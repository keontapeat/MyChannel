#!/usr/bin/env python3
"""
Step 4: Update all Cloud Run services to call their real Vertex AI endpoints.
Reads endpoint IDs from endpoint_ids.txt and updates each service env var.
"""

import subprocess
import os

PROJECT_ID = "mychannel-ca26d"
REGION = "us-central1"

# Maps Cloud Run service name -> model name in endpoint_ids.txt
SERVICE_TO_MODEL = {
    "churn-predictor":                  "churn-predictor-v1",
    "feed-personalization":             "feed-personalization-v1",
    "search-ranking":                   "search-ranking-v1",
    "notification-optimizer":           "notification-optimizer-v1",
    "subscription-pricing":             "subscription-pricing-v1",
    "rtb-bidding-predictor":            "rtb-bidding-v1",
    "fraud-detection-predictor":        "fraud-detection-v1",
    "content-moderation":               "content-moderation-v1",
    "brand-safety-ml-predictor":        "brand-safety-v1",
    "advanced-targeting-predictor":     "advanced-targeting-v1",
    "engagement-predictor":             "engagement-predictor-v1",
    "viral-prediction":                 "viral-prediction-v1",
    "lifetime-value-ai":                "lifetime-value-v1",
    "fraud-detection":                  "fraud-detection-v1",
    "brand-safety":                     "brand-safety-v1",
    "brand-safety-ai":                  "brand-safety-v1",
    "search-ranking-ai":                "search-ranking-v1",
    "retention-optimizer-ai":           "churn-predictor-v1",
    "churn-prevention":                 "churn-predictor-v1",
    "engagement-booster-ai":            "engagement-predictor-v1",
    "audience-lookalike-predictor":     "advanced-targeting-v1",
    "audience-segmentation-ai":         "advanced-targeting-v1",
    "real-time-bidding-ai":             "rtb-bidding-v1",
    "ad-optimization":                  "rtb-bidding-v1",
    "ad-quality-scorer-predictor":      "engagement-predictor-v1",
    "contextual-analysis-predictor":    "brand-safety-v1",
    "competitor-intelligence-predictor":"engagement-predictor-v1",
    "viewability-prediction-predictor": "engagement-predictor-v1",
    "spam-detection":                   "content-moderation-v1",
    "moderation-ai-v2":                 "content-moderation-v1",
    "hyper-personalization-ai":         "feed-personalization-v1",
    "viral-prediction":                 "viral-prediction-v1",
    "trend-forecaster":                 "viral-prediction-v1",
    "watch-time-optimizer":             "engagement-predictor-v1",
    "subscription-growth-ai":           "subscription-pricing-v1",
    "membership-optimizer":             "subscription-pricing-v1",
    "tipping-ai":                       "lifetime-value-v1",
    "tipping-maximizer":                "lifetime-value-v1",
}


def load_endpoint_ids(filepath="pipeline/endpoint_ids.txt") -> dict:
    """Load trained Vertex AI endpoint resource names."""
    endpoint_map = {}
    if not os.path.exists(filepath):
        print(f"ERROR: {filepath} not found. Run 03_train_vertex_ai_models.py first.")
        return {}
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if "=" in line:
                model_name, endpoint_id = line.split("=", 1)
                endpoint_map[model_name.strip()] = endpoint_id.strip()
    print(f"Loaded {len(endpoint_map)} endpoint IDs")
    return endpoint_map


def update_service(service_name: str, endpoint_resource: str, model_name: str):
    """Update a Cloud Run service with the real Vertex AI endpoint ID."""
    # Extract just the endpoint ID from full resource name
    # Format: projects/PROJECT/locations/REGION/endpoints/ENDPOINT_ID
    endpoint_id = endpoint_resource.split("/")[-1]

    cmd = [
        "gcloud", "run", "services", "update", service_name,
        f"--region={REGION}",
        f"--project={PROJECT_ID}",
        f"--update-env-vars=VERTEX_AI_ENDPOINT_ID={endpoint_id},MODEL_NAME={model_name},PROJECT_ID={PROJECT_ID},REGION={REGION}",
        "--quiet"
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  Updated {service_name} -> endpoint {endpoint_id}")
        return True
    else:
        print(f"  FAILED {service_name}: {result.stderr.strip()[:100]}")
        return False


if __name__ == "__main__":
    endpoint_map = load_endpoint_ids()
    if not endpoint_map:
        exit(1)

    print(f"\nUpdating {len(SERVICE_TO_MODEL)} Cloud Run services with real Vertex AI endpoints...\n")

    success = 0
    failed = []

    for service_name, model_name in SERVICE_TO_MODEL.items():
        endpoint_resource = endpoint_map.get(model_name)
        if not endpoint_resource:
            print(f"  SKIP {service_name}: no endpoint for {model_name}")
            continue
        if update_service(service_name, endpoint_resource, model_name):
            success += 1
        else:
            failed.append(service_name)

    print(f"\n{'='*50}")
    print(f"Done. {success}/{len(SERVICE_TO_MODEL)} services updated.")
    if failed:
        print(f"Failed: {failed}")
    print("\nNext step: Run 05_rebuild_services_with_real_vertex.sh to redeploy updated code")
