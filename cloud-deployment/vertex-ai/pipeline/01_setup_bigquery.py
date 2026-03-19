#!/usr/bin/env python3
"""
Step 1: Create BigQuery dataset and all training data schemas
for every real Vertex AI ML agent on MyChannel.
"""

from google.cloud import bigquery

PROJECT_ID = "mychannel-ca26d"
DATASET_ID = "vertex_ai_training"
LOCATION = "US"

client = bigquery.Client(project=PROJECT_ID)


def create_dataset():
    dataset_ref = f"{PROJECT_ID}.{DATASET_ID}"
    dataset = bigquery.Dataset(dataset_ref)
    dataset.location = LOCATION
    dataset.description = "Training data for all MyChannel Vertex AI ML agents"
    try:
        client.create_dataset(dataset, exists_ok=True)
        print(f"Dataset {DATASET_ID} ready")
    except Exception as e:
        print(f"Dataset error: {e}")


TABLES = {
    # --- USER BEHAVIOR ---
    "churn_training": [
        bigquery.SchemaField("user_id", "STRING"),
        bigquery.SchemaField("days_since_last_active", "INTEGER"),
        bigquery.SchemaField("watch_time_change_7d", "FLOAT"),
        bigquery.SchemaField("sessions_this_week", "INTEGER"),
        bigquery.SchemaField("sessions_last_week", "INTEGER"),
        bigquery.SchemaField("is_subscriber", "BOOLEAN"),
        bigquery.SchemaField("notifications_disabled", "BOOLEAN"),
        bigquery.SchemaField("interactions_7d", "INTEGER"),
        bigquery.SchemaField("total_watch_minutes_30d", "FLOAT"),
        bigquery.SchemaField("followed_creators_count", "INTEGER"),
        bigquery.SchemaField("avg_session_minutes", "FLOAT"),
        bigquery.SchemaField("days_on_platform", "INTEGER"),
        bigquery.SchemaField("label", "INTEGER"),  # 1=churned, 0=retained
    ],
    "feed_personalization_training": [
        bigquery.SchemaField("user_id", "STRING"),
        bigquery.SchemaField("video_id", "STRING"),
        bigquery.SchemaField("category", "STRING"),
        bigquery.SchemaField("creator_id", "STRING"),
        bigquery.SchemaField("hours_since_published", "FLOAT"),
        bigquery.SchemaField("like_ratio", "FLOAT"),
        bigquery.SchemaField("is_trending", "BOOLEAN"),
        bigquery.SchemaField("user_top_category_1", "STRING"),
        bigquery.SchemaField("user_top_category_2", "STRING"),
        bigquery.SchemaField("follows_creator", "BOOLEAN"),
        bigquery.SchemaField("user_avg_watch_pct", "FLOAT"),
        bigquery.SchemaField("label", "FLOAT"),  # watch_percentage 0-1
    ],
    "search_ranking_training": [
        bigquery.SchemaField("query", "STRING"),
        bigquery.SchemaField("video_id", "STRING"),
        bigquery.SchemaField("title_match_score", "FLOAT"),
        bigquery.SchemaField("tag_match_score", "FLOAT"),
        bigquery.SchemaField("view_count", "INTEGER"),
        bigquery.SchemaField("like_ratio", "FLOAT"),
        bigquery.SchemaField("hours_since_published", "FLOAT"),
        bigquery.SchemaField("is_trending", "BOOLEAN"),
        bigquery.SchemaField("category_match", "BOOLEAN"),
        bigquery.SchemaField("creator_followed", "BOOLEAN"),
        bigquery.SchemaField("label", "INTEGER"),  # 1=clicked, 0=skipped
    ],
    "notification_optimizer_training": [
        bigquery.SchemaField("user_id", "STRING"),
        bigquery.SchemaField("notification_type", "STRING"),
        bigquery.SchemaField("send_hour", "INTEGER"),
        bigquery.SchemaField("day_of_week", "INTEGER"),
        bigquery.SchemaField("notifications_received_today", "INTEGER"),
        bigquery.SchemaField("creator_id", "STRING"),
        bigquery.SchemaField("follows_creator", "BOOLEAN"),
        bigquery.SchemaField("category", "STRING"),
        bigquery.SchemaField("user_active_hour", "INTEGER"),
        bigquery.SchemaField("label", "INTEGER"),  # 1=opened, 0=ignored
    ],
    "subscription_pricing_training": [
        bigquery.SchemaField("user_id", "STRING"),
        bigquery.SchemaField("device_type", "STRING"),
        bigquery.SchemaField("country", "STRING"),
        bigquery.SchemaField("avg_daily_watch_minutes", "FLOAT"),
        bigquery.SchemaField("past_in_app_purchases", "INTEGER"),
        bigquery.SchemaField("followed_creators_count", "INTEGER"),
        bigquery.SchemaField("days_on_platform", "INTEGER"),
        bigquery.SchemaField("is_creator", "BOOLEAN"),
        bigquery.SchemaField("churn_risk_score", "FLOAT"),
        bigquery.SchemaField("current_tier", "STRING"),
        bigquery.SchemaField("label", "STRING"),  # tier they upgraded to
    ],
    # --- ADS ---
    "rtb_bidding_training": [
        bigquery.SchemaField("impression_id", "STRING"),
        bigquery.SchemaField("user_engagement_score", "FLOAT"),
        bigquery.SchemaField("placement_type", "INTEGER"),
        bigquery.SchemaField("hour_of_day", "INTEGER"),
        bigquery.SchemaField("day_of_week", "INTEGER"),
        bigquery.SchemaField("device_type", "STRING"),
        bigquery.SchemaField("geo", "STRING"),
        bigquery.SchemaField("avg_winning_bid", "FLOAT"),
        bigquery.SchemaField("historical_ctr", "FLOAT"),
        bigquery.SchemaField("historical_cvr", "FLOAT"),
        bigquery.SchemaField("label", "FLOAT"),  # winning bid amount
    ],
    "fraud_detection_training": [
        bigquery.SchemaField("event_id", "STRING"),
        bigquery.SchemaField("user_id", "STRING"),
        bigquery.SchemaField("ip_address_hash", "STRING"),
        bigquery.SchemaField("device_fingerprint", "STRING"),
        bigquery.SchemaField("clicks_per_minute", "FLOAT"),
        bigquery.SchemaField("views_per_minute", "FLOAT"),
        bigquery.SchemaField("account_age_days", "INTEGER"),
        bigquery.SchemaField("vpn_detected", "BOOLEAN"),
        bigquery.SchemaField("datacenter_ip", "BOOLEAN"),
        bigquery.SchemaField("same_ip_accounts", "INTEGER"),
        bigquery.SchemaField("label", "INTEGER"),  # 1=fraud, 0=legit
    ],
    "content_moderation_training": [
        bigquery.SchemaField("content_id", "STRING"),
        bigquery.SchemaField("content_type", "STRING"),
        bigquery.SchemaField("text_toxicity_score", "FLOAT"),
        bigquery.SchemaField("has_url", "BOOLEAN"),
        bigquery.SchemaField("has_phone", "BOOLEAN"),
        bigquery.SchemaField("caps_ratio", "FLOAT"),
        bigquery.SchemaField("special_char_ratio", "FLOAT"),
        bigquery.SchemaField("word_count", "INTEGER"),
        bigquery.SchemaField("prior_violations", "INTEGER"),
        bigquery.SchemaField("account_age_days", "INTEGER"),
        bigquery.SchemaField("label", "STRING"),  # safe/spam/toxic/nsfw
    ],
    "brand_safety_training": [
        bigquery.SchemaField("video_id", "STRING"),
        bigquery.SchemaField("title_toxicity", "FLOAT"),
        bigquery.SchemaField("description_toxicity", "FLOAT"),
        bigquery.SchemaField("category", "STRING"),
        bigquery.SchemaField("has_age_restriction", "BOOLEAN"),
        bigquery.SchemaField("prior_violations", "INTEGER"),
        bigquery.SchemaField("channel_trust_score", "FLOAT"),
        bigquery.SchemaField("label", "STRING"),  # safe/restricted/blocked
    ],
    "advanced_targeting_training": [
        bigquery.SchemaField("user_id", "STRING"),
        bigquery.SchemaField("ad_id", "STRING"),
        bigquery.SchemaField("age_bucket", "STRING"),
        bigquery.SchemaField("gender", "STRING"),
        bigquery.SchemaField("country", "STRING"),
        bigquery.SchemaField("top_category", "STRING"),
        bigquery.SchemaField("device_type", "STRING"),
        bigquery.SchemaField("hour_of_day", "INTEGER"),
        bigquery.SchemaField("is_subscriber", "BOOLEAN"),
        bigquery.SchemaField("lifetime_value", "FLOAT"),
        bigquery.SchemaField("label", "INTEGER"),  # 1=converted, 0=no
    ],
    "engagement_predictor_training": [
        bigquery.SchemaField("video_id", "STRING"),
        bigquery.SchemaField("creator_id", "STRING"),
        bigquery.SchemaField("title_length", "INTEGER"),
        bigquery.SchemaField("has_thumbnail", "BOOLEAN"),
        bigquery.SchemaField("duration_seconds", "INTEGER"),
        bigquery.SchemaField("category", "STRING"),
        bigquery.SchemaField("upload_hour", "INTEGER"),
        bigquery.SchemaField("creator_subscriber_count", "INTEGER"),
        bigquery.SchemaField("creator_avg_views", "FLOAT"),
        bigquery.SchemaField("label", "FLOAT"),  # actual view count / subscriber count
    ],
    "viral_prediction_training": [
        bigquery.SchemaField("video_id", "STRING"),
        bigquery.SchemaField("views_1h", "INTEGER"),
        bigquery.SchemaField("views_6h", "INTEGER"),
        bigquery.SchemaField("shares_1h", "INTEGER"),
        bigquery.SchemaField("comments_1h", "INTEGER"),
        bigquery.SchemaField("likes_1h", "INTEGER"),
        bigquery.SchemaField("velocity_score", "FLOAT"),
        bigquery.SchemaField("creator_subscriber_count", "INTEGER"),
        bigquery.SchemaField("category", "STRING"),
        bigquery.SchemaField("label", "INTEGER"),  # 1=went viral, 0=did not
    ],
    "lifetime_value_training": [
        bigquery.SchemaField("user_id", "STRING"),
        bigquery.SchemaField("days_on_platform", "INTEGER"),
        bigquery.SchemaField("total_watch_minutes", "FLOAT"),
        bigquery.SchemaField("total_spend", "FLOAT"),
        bigquery.SchemaField("subscription_months", "INTEGER"),
        bigquery.SchemaField("tip_count", "INTEGER"),
        bigquery.SchemaField("merch_purchases", "INTEGER"),
        bigquery.SchemaField("device_type", "STRING"),
        bigquery.SchemaField("country", "STRING"),
        bigquery.SchemaField("label", "FLOAT"),  # predicted 12-month LTV
    ],
}


def create_tables():
    for table_name, schema in TABLES.items():
        table_ref = f"{PROJECT_ID}.{DATASET_ID}.{table_name}"
        table = bigquery.Table(table_ref, schema=schema)
        try:
            client.create_table(table, exists_ok=True)
            print(f"  Table ready: {table_name}")
        except Exception as e:
            print(f"  Table error {table_name}: {e}")


if __name__ == "__main__":
    print("Setting up BigQuery dataset and training tables...")
    create_dataset()
    print("Creating training tables...")
    create_tables()
    print(f"\nDone. {len(TABLES)} tables created in {PROJECT_ID}.{DATASET_ID}")
