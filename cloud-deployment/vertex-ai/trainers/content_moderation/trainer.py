"""Content Moderation — Vertex AI Custom Trainer"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_trainer import load_bq_table, save_model
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

def train():
    print("[*] Loading content_moderation_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "content_moderation_training")
    print(f"[*] Loaded {len(df)} rows")

    cat_cols = ["content_type", "language", "reported_reason"]
    encoders = {}
    for col in cat_cols:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
            encoders[col] = le

    feature_cols = ["toxicity_score", "profanity_count", "hate_speech_score",
                    "violence_score", "nudity_score", "spam_score",
                    "report_count", "report_rate", "creator_strike_history",
                    "content_type", "language", "reported_reason",
                    "account_age_days", "prior_violations"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["should_remove"] if "should_remove" in df.columns else df["label"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = RandomForestClassifier(n_estimators=400, max_depth=10,
                                    class_weight="balanced", n_jobs=-1, random_state=42)
    model.fit(X_train, y_train)

    auc = roc_auc_score(y_test, model.predict_proba(X_test)[:, 1])
    print(f"[✓] AUC: {auc:.4f}")
    save_model(model, scaler, encoders, "content-moderation", {"auc": round(auc, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
