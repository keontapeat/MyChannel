"""Lifetime Value Predictor — Vertex AI Custom Trainer"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_trainer import load_bq_table, save_model
import pandas as pd
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_squared_error
import numpy as np

def train():
    print("[*] Loading lifetime_value_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "lifetime_value_training")
    print(f"[*] Loaded {len(df)} rows")

    cat_cols = ["country", "acquisition_channel", "subscription_tier"]
    encoders = {}
    for col in cat_cols:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
            encoders[col] = le

    feature_cols = ["account_age_days", "total_spend", "avg_monthly_spend",
                    "subscription_renewals", "churn_events", "reactivations",
                    "watch_time_total_hours", "creator_count_followed",
                    "country", "acquisition_channel", "subscription_tier",
                    "referrals_made", "in_app_purchases", "tip_count"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["ltv_12m"] if "ltv_12m" in df.columns else df["lifetime_value"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = GradientBoostingRegressor(n_estimators=300, max_depth=6, learning_rate=0.04, random_state=42)
    model.fit(X_train, y_train)

    rmse = np.sqrt(mean_squared_error(y_test, model.predict(X_test)))
    print(f"[✓] RMSE: {rmse:.4f}")
    save_model(model, scaler, encoders, "lifetime-value", {"rmse": round(rmse, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
