"""Search Ranking — Vertex AI Custom Trainer"""
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
    print("[*] Loading search_ranking_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "search_ranking_training")
    print(f"[*] Loaded {len(df)} rows")

    cat_cols = ["content_type", "language"]
    encoders = {}
    for col in cat_cols:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
            encoders[col] = le

    feature_cols = ["query_match_score", "title_match_score", "description_match_score",
                    "tag_match_score", "view_count", "like_ratio", "avg_watch_pct",
                    "recency_score", "creator_authority_score", "engagement_rate",
                    "ctr_from_search", "content_type", "language", "video_duration_seconds"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["relevance_score"] if "relevance_score" in df.columns else df["click_rank"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = GradientBoostingRegressor(n_estimators=300, max_depth=5, learning_rate=0.05, random_state=42)
    model.fit(X_train, y_train)

    rmse = np.sqrt(mean_squared_error(y_test, model.predict(X_test)))
    print(f"[✓] RMSE: {rmse:.4f}")
    save_model(model, scaler, encoders, "search-ranking", {"rmse": round(rmse, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
