"""Base trainer shared by all MyChannel Vertex AI custom training jobs."""
import os
import argparse
import json
import pickle
import numpy as np
import pandas as pd
from google.cloud import bigquery, storage
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import (roc_auc_score, mean_squared_error,
                             accuracy_score, classification_report)
import joblib

PROJECT = os.environ.get("GOOGLE_CLOUD_PROJECT", "mychannel-ca26d")
REGION = os.environ.get("REGION", "us-central1")
BUCKET = os.environ.get("AIP_MODEL_DIR", "gs://mychannel-ml-data/models")


def load_bq_table(dataset: str, table: str) -> pd.DataFrame:
    client = bigquery.Client(project=PROJECT)
    return client.query(
        f"SELECT * FROM `{PROJECT}.{dataset}.{table}`"
    ).to_dataframe()


def save_model(model, scaler, encoders: dict, model_name: str, metrics: dict):
    """Save model artifacts to GCS AIP_MODEL_DIR."""
    model_dir = os.environ.get("AIP_MODEL_DIR", f"/tmp/{model_name}")
    os.makedirs(model_dir, exist_ok=True)

    joblib.dump(model, os.path.join(model_dir, "model.joblib"))
    joblib.dump(scaler, os.path.join(model_dir, "scaler.joblib"))
    joblib.dump(encoders, os.path.join(model_dir, "encoders.joblib"))

    with open(os.path.join(model_dir, "metrics.json"), "w") as f:
        json.dump(metrics, f, indent=2)

    print(f"[✓] Model saved to {model_dir}")
    print(f"[✓] Metrics: {json.dumps(metrics, indent=2)}")
