"""Churn Predictor — Vertex AI Custom Trainer"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_trainer import load_bq_table, save_model
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

def train():
    print("[*] Loading churn_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "churn_training")
    print(f"[*] Loaded {len(df)} rows")

    feature_cols = ["days_since_last_active", "session_count_30d", "avg_session_duration",
                    "videos_watched_30d", "likes_given_30d", "comments_30d",
                    "subscription_age_days", "paid_subscriber", "notifications_clicked_pct",
                    "creator_followed_count", "watch_time_minutes_30d"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["churned"] if "churned" in df.columns else df["label"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = RandomForestClassifier(n_estimators=300, max_depth=8, n_jobs=-1, random_state=42)
    model.fit(X_train, y_train)

    auc = roc_auc_score(y_test, model.predict_proba(X_test)[:, 1])
    print(f"[✓] AUC: {auc:.4f}")
    save_model(model, scaler, {}, "churn-predictor", {"auc": round(auc, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
