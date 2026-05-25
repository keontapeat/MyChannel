"""Advanced Targeting — Vertex AI Custom Trainer"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from base_trainer import load_bq_table, save_model
import pandas as pd
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

def train():
    print("[*] Loading advanced_targeting_training from BigQuery...")
    df = load_bq_table("vertex_ai_training", "advanced_targeting_training")
    print(f"[*] Loaded {len(df)} rows")

    cat_cols = ["country", "device_type", "os", "interest_segment"]
    encoders = {}
    for col in cat_cols:
        if col in df.columns:
            le = LabelEncoder()
            df[col] = le.fit_transform(df[col].astype(str))
            encoders[col] = le

    feature_cols = ["age_bucket", "gender_encoded", "interest_segment", "country",
                    "device_type", "os", "watch_time_hours", "category_affinity_score",
                    "purchase_intent_score", "brand_affinity_score", "lookalike_score",
                    "retargeting_flag", "days_since_last_ad_click", "ad_frequency_30d"]
    feature_cols = [c for c in feature_cols if c in df.columns]

    X = df[feature_cols].fillna(0)
    y = df["will_convert"] if "will_convert" in df.columns else df["label"]

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)

    model = GradientBoostingClassifier(n_estimators=300, max_depth=6, learning_rate=0.04, random_state=42)
    model.fit(X_train, y_train)

    auc = roc_auc_score(y_test, model.predict_proba(X_test)[:, 1])
    print(f"[✓] AUC: {auc:.4f}")
    save_model(model, scaler, encoders, "advanced-targeting", {"auc": round(auc, 4), "features": feature_cols})

if __name__ == "__main__":
    train()
