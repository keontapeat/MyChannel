"""Fraud Detection — Vertex AI Custom Trainer"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_trainer import load_bq_table, save_model
import pandas as pd
from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

def train():
    print("[*] Loading fraud_detection_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "fraud_detection_training")
    print(f"[*] Loaded {len(df)} rows")

    feature_cols = ["transaction_amount", "transactions_per_hour", "unique_ips_24h",
                    "account_age_days", "failed_payment_count", "country_mismatch",
                    "device_fingerprint_new", "velocity_score", "dispute_history_count",
                    "chargebacks_30d", "unusual_hour", "vpn_detected", "proxy_detected"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["is_fraud"] if "is_fraud" in df.columns else df["label"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = RandomForestClassifier(n_estimators=500, max_depth=10, class_weight="balanced",
                                    n_jobs=-1, random_state=42)
    model.fit(X_train, y_train)

    auc = roc_auc_score(y_test, model.predict_proba(X_test)[:, 1])
    print(f"[✓] AUC: {auc:.4f}")
    save_model(model, scaler, {}, "fraud-detection", {"auc": round(auc, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
