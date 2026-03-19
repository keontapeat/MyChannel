"""Brand Safety — Vertex AI Custom Trainer"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_trainer import load_bq_table, save_model
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

def train():
    print("[*] Loading brand_safety_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "brand_safety_training")
    print(f"[*] Loaded {len(df)} rows")

    cat_cols = ["content_category", "language", "channel_type"]
    encoders = {}
    for col in cat_cols:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
            encoders[col] = le

    feature_cols = ["toxicity_score", "violence_score", "adult_content_score",
                    "controversy_score", "brand_mention_score", "sentiment_negative",
                    "content_category", "language", "channel_type",
                    "creator_brand_safety_history", "avg_comment_toxicity",
                    "report_rate_30d", "verified_creator"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["brand_safe"] if "brand_safe" in df.columns else df["label"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = GradientBoostingClassifier(n_estimators=300, max_depth=5, learning_rate=0.05, random_state=42)
    model.fit(X_train, y_train)

    auc = roc_auc_score(y_test, model.predict_proba(X_test)[:, 1])
    print(f"[✓] AUC: {auc:.4f}")
    save_model(model, scaler, encoders, "brand-safety", {"auc": round(auc, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
