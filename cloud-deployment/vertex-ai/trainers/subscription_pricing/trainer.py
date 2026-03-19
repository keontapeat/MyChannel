"""Subscription Pricing — Vertex AI Custom Trainer"""
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
    print("[*] Loading subscription_pricing_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "subscription_pricing_training")
    print(f"[*] Loaded {len(df)} rows")

    cat_cols = ["country", "subscription_tier", "payment_method"]
    encoders = {}
    for col in cat_cols:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
            encoders[col] = le

    feature_cols = ["user_age_days", "watch_time_hours_30d", "videos_watched_30d",
                    "creator_count_followed", "country", "subscription_tier",
                    "prev_subscription_price", "ltv_estimate", "churn_risk_score",
                    "engagement_score", "payment_method", "income_proxy"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["optimal_price"] if "optimal_price" in df.columns else df["price"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = GradientBoostingRegressor(n_estimators=200, max_depth=5, learning_rate=0.05, random_state=42)
    model.fit(X_train, y_train)

    rmse = np.sqrt(mean_squared_error(y_test, model.predict(X_test)))
    print(f"[✓] RMSE: {rmse:.4f}")
    save_model(model, scaler, encoders, "subscription-pricing", {"rmse": round(rmse, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
