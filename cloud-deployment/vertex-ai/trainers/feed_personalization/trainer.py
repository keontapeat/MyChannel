"""Feed Personalization — Vertex AI Custom Trainer"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_trainer import load_bq_table, save_model
import numpy as np
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

def train():
    print("[*] Loading feed_personalization_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "feed_personalization_training")
    print(f"[*] Loaded {len(df)} rows")

    cat_cols = ["category", "user_top_category_1", "user_top_category_2"]
    encoders = {}
    for col in cat_cols:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
            encoders[col] = le

    bool_cols = ["follows_creator", "is_trending"]
    for col in bool_cols:
        if col in df.columns:
            df[col] = df[col].astype(int)

    feature_cols = ["like_ratio", "user_avg_watch_pct", "hours_since_published",
                    "is_trending", "follows_creator", "category",
                    "user_top_category_1", "user_top_category_2"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["label"] if "label" in df.columns else (df["watch_pct"] > 0.5).astype(int)

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = GradientBoostingClassifier(n_estimators=200, max_depth=5, learning_rate=0.05, random_state=42)
    model.fit(X_train, y_train)

    y_pred_proba = model.predict_proba(X_test)[:, 1]
    auc = roc_auc_score(y_test, y_pred_proba)
    print(f"[✓] AUC: {auc:.4f}")

    metrics = {"auc": round(auc, 4), "train_rows": len(X_train), "features": feature_cols}
    save_model(model, scaler, encoders, "feed-personalization", metrics)

if __name__ == "__main__":
    train()
