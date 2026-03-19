"""Watch Time Predictor — Vertex AI Custom Trainer"""
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
    print("[*] Loading from BigQuery or generating synthetic data...")
    try:
        df = load_bq_table("vertex_ai_training", "feed_personalization_training")
    except Exception:
        np.random.seed(42)
        n = 50000
        df = pd.DataFrame({
            "video_duration_seconds": np.random.randint(30, 3600, n),
            "like_ratio": np.random.beta(5, 2, n),
            "creator_avg_watch_pct": np.random.beta(4, 3, n),
            "user_avg_watch_pct": np.random.beta(4, 3, n),
            "content_category_encoded": np.random.randint(0, 20, n),
            "upload_hour": np.random.randint(0, 24, n),
            "device_type_encoded": np.random.randint(0, 4, n),
            "is_trending": np.random.randint(0, 2, n),
            "follows_creator": np.random.randint(0, 2, n),
            "hook_score": np.random.beta(3, 2, n),
        })
        df["watch_pct"] = (0.3 * df["like_ratio"] + 0.3 * df["user_avg_watch_pct"] +
                           0.2 * df["hook_score"] + 0.2 * df["follows_creator"] +
                           np.random.normal(0, 0.05, n)).clip(0, 1)

    feature_cols = ["video_duration_seconds", "like_ratio", "creator_avg_watch_pct",
                    "user_avg_watch_pct", "content_category_encoded", "upload_hour",
                    "device_type_encoded", "is_trending", "follows_creator", "hook_score"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["watch_pct"] if "watch_pct" in df.columns else df["avg_watch_pct"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = GradientBoostingRegressor(n_estimators=300, max_depth=5, learning_rate=0.05, random_state=42)
    model.fit(X_train, y_train)

    rmse = np.sqrt(mean_squared_error(y_test, model.predict(X_test)))
    print(f"[✓] RMSE: {rmse:.4f}")
    save_model(model, scaler, {}, "watch-time-predictor", {"rmse": round(rmse, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
