#!/usr/bin/env python3
"""
Step 3: Train real Vertex AI AutoML models for every MyChannel ML agent.
Uses AutoML Tabular - no ML expertise needed, just point at BigQuery table.
"""

import time
from google.cloud import aiplatform

PROJECT_ID = "mychannel-ca26d"
REGION = "us-central1"
DATASET_ID = "vertex_ai_training"
BUCKET = "gs://mychannel-ml-data"

aiplatform.init(project=PROJECT_ID, location=REGION, staging_bucket=BUCKET)


MODELS = [
    {
        "name": "churn-predictor-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.churn_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "feed-personalization-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.feed_personalization_training",
        "target_column": "label",
        "task": "regression",
        "budget_hours": 1,
    },
    {
        "name": "search-ranking-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.search_ranking_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "notification-optimizer-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.notification_optimizer_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "subscription-pricing-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.subscription_pricing_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "rtb-bidding-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.rtb_bidding_training",
        "target_column": "label",
        "task": "regression",
        "budget_hours": 1,
    },
    {
        "name": "fraud-detection-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.fraud_detection_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "content-moderation-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.content_moderation_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "brand-safety-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.brand_safety_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "advanced-targeting-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.advanced_targeting_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "engagement-predictor-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.engagement_predictor_training",
        "target_column": "label",
        "task": "regression",
        "budget_hours": 1,
    },
    {
        "name": "viral-prediction-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.viral_prediction_training",
        "target_column": "label",
        "task": "classification",
        "budget_hours": 1,
    },
    {
        "name": "lifetime-value-v1",
        "bq_table": f"bq://{PROJECT_ID}.{DATASET_ID}.lifetime_value_training",
        "target_column": "label",
        "task": "regression",
        "budget_hours": 1,
    },
]


def train_model(model_config: dict) -> str:
    """Train a single AutoML Tabular model and return endpoint resource name."""
    name = model_config["name"]
    print(f"\n[{name}] Creating dataset from BigQuery...")

    dataset = aiplatform.TabularDataset.create(
        display_name=f"{name}-dataset",
        bq_source=model_config["bq_table"],
    )
    print(f"[{name}] Dataset created: {dataset.resource_name}")

    print(f"[{name}] Launching AutoML training job (budget: {model_config['budget_hours']}h)...")

    if model_config["task"] == "classification":
        job = aiplatform.AutoMLTabularTrainingJob(
            display_name=f"{name}-training",
            optimization_prediction_type="classification",
            optimization_objective="maximize-au-roc",
        )
    else:
        job = aiplatform.AutoMLTabularTrainingJob(
            display_name=f"{name}-training",
            optimization_prediction_type="regression",
            optimization_objective="minimize-rmse",
        )

    model = job.run(
        dataset=dataset,
        target_column=model_config["target_column"],
        training_fraction_split=0.8,
        validation_fraction_split=0.1,
        test_fraction_split=0.1,
        budget_milli_node_hours=model_config["budget_hours"] * 1000,
        model_display_name=name,
        disable_early_stopping=False,
        sync=True,
    )

    print(f"[{name}] Model trained: {model.resource_name}")

    print(f"[{name}] Deploying to endpoint...")
    endpoint = model.deploy(
        deployed_model_display_name=name,
        machine_type="n1-standard-4",
        min_replica_count=1,
        max_replica_count=3,
        traffic_percentage=100,
        sync=True,
    )

    print(f"[{name}] Endpoint live: {endpoint.resource_name}")
    return endpoint.resource_name


def save_endpoint_ids(endpoint_map: dict):
    """Save endpoint resource names to file for Step 4."""
    with open("pipeline/endpoint_ids.txt", "w") as f:
        for model_name, endpoint_id in endpoint_map.items():
            f.write(f"{model_name}={endpoint_id}\n")
    print(f"\nEndpoint IDs saved to pipeline/endpoint_ids.txt")


if __name__ == "__main__":
    print(f"Training {len(MODELS)} real Vertex AI AutoML models...")
    print("This will take 1-3 hours per model. Running all in sequence.\n")

    endpoint_map = {}
    failed = []

    for model_config in MODELS:
        try:
            endpoint_resource = train_model(model_config)
            endpoint_map[model_config["name"]] = endpoint_resource
            print(f"[{model_config['name']}] SUCCESS")
        except Exception as e:
            print(f"[{model_config['name']}] FAILED: {e}")
            failed.append(model_config["name"])

    save_endpoint_ids(endpoint_map)

    print(f"\n{'='*50}")
    print(f"Training complete.")
    print(f"  Successful: {len(endpoint_map)}/{len(MODELS)}")
    if failed:
        print(f"  Failed: {failed}")
    print(f"\nNext step: Run 04_update_cloud_run_services.py")
