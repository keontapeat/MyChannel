#!/usr/bin/env python3
"""
Step 2b: Seed synthetic training data into BigQuery tables that have < 1000 rows.
Realistic distributions based on actual MyChannel platform patterns.
AutoML needs >= 1000 rows to train. Real data will replace this as platform grows.
"""

import random
import math
from google.cloud import bigquery

PROJECT_ID = "mychannel-ca26d"
DATASET_ID = "vertex_ai_training"
TARGET_ROWS = 5000

client = bigquery.Client(project=PROJECT_ID)

CATEGORIES = ["gaming", "music", "sports", "comedy", "education", "tech", "fitness", "cooking", "travel", "news"]
COUNTRIES = ["US", "CA", "GB", "AU", "IN", "BR", "MX", "DE", "FR", "JP"]
DEVICES = ["ios", "android", "web"]
TIERS = ["free", "basic", "pro", "creator"]
NOTIF_TYPES = ["new_video", "live_stream", "achievement", "comment_reply", "follow", "milestone"]


def r(): return random.random()
def ri(a, b): return random.randint(a, b)
def rc(lst): return random.choice(lst)
def rg(): return rc(["male", "female", "other"])


def table(name): return f"{PROJECT_ID}.{DATASET_ID}.{name}"


def current_row_count(table_name: str) -> int:
    result = client.query(f"SELECT COUNT(*) as cnt FROM `{table(table_name)}`").result()
    return list(result)[0].cnt


def insert_rows(table_id: str, rows: list):
    if not rows:
        return
    errors = client.insert_rows_json(table_id, rows)
    if errors:
        print(f"  Insert errors: {errors[:2]}")


# ─── CHURN ───────────────────────────────────────────────────────────────────

def seed_churn(n: int):
    rows = []
    for i in range(n):
        churned = r() < 0.25
        days_inactive = ri(0, 7) if not churned else ri(14, 90)
        rows.append({
            "user_id": f"seed_user_{i}",
            "days_since_last_active": days_inactive,
            "watch_time_change_7d": round(random.uniform(-0.8, 0.5) if churned else random.uniform(-0.2, 1.0), 4),
            "sessions_this_week": ri(0, 2) if churned else ri(3, 20),
            "sessions_last_week": ri(3, 15),
            "is_subscriber": r() > (0.8 if churned else 0.4),
            "notifications_disabled": r() < (0.7 if churned else 0.2),
            "interactions_7d": ri(0, 2) if churned else ri(5, 50),
            "total_watch_minutes_30d": round(random.uniform(0, 60) if churned else random.uniform(60, 600), 2),
            "followed_creators_count": ri(0, 3) if churned else ri(5, 50),
            "avg_session_minutes": round(random.uniform(1, 5) if churned else random.uniform(10, 45), 2),
            "days_on_platform": ri(1, 730),
            "label": 1 if churned else 0,
        })
    return rows


# ─── FEED PERSONALIZATION ────────────────────────────────────────────────────

def seed_feed(n: int):
    rows = []
    for i in range(n):
        follows = r() < 0.3
        same_cat = r() < 0.5
        watch_pct = round(random.betavariate(2, 2), 4)
        rows.append({
            "user_id": f"seed_user_{ri(0, 500)}",
            "video_id": f"seed_video_{ri(0, 1000)}",
            "category": rc(CATEGORIES),
            "creator_id": f"seed_creator_{ri(0, 200)}",
            "hours_since_published": round(random.uniform(0, 720), 2),
            "like_ratio": round(random.betavariate(5, 2), 4),
            "is_trending": r() < 0.1,
            "user_top_category_1": rc(CATEGORIES),
            "user_top_category_2": rc(CATEGORIES),
            "follows_creator": follows,
            "user_avg_watch_pct": round(random.betavariate(3, 2), 4),
            "label": round(watch_pct * (1.3 if follows else 1.0) * (1.2 if same_cat else 1.0), 4),
        })
    return rows


# ─── SEARCH RANKING ──────────────────────────────────────────────────────────

def seed_search(n: int):
    rows = []
    for i in range(n):
        title_match = round(r(), 4)
        tag_match = round(r() * 0.5, 4)
        follows = r() < 0.2
        views = ri(0, 5000000)
        clicked = 1 if (title_match > 0.6 or follows or views > 500000) and r() < 0.7 else 0
        rows.append({
            "query": rc(["gaming highlights", "music videos", "funny moments", "tutorial", "live stream", "news today"]),
            "video_id": f"seed_video_{ri(0, 1000)}",
            "title_match_score": title_match,
            "tag_match_score": tag_match,
            "view_count": views,
            "like_ratio": round(random.betavariate(5, 2), 4),
            "hours_since_published": round(random.uniform(0, 8760), 2),
            "is_trending": r() < 0.08,
            "category_match": r() < 0.5,
            "creator_followed": follows,
            "label": clicked,
        })
    return rows


# ─── NOTIFICATION OPTIMIZER ──────────────────────────────────────────────────

def seed_notifications(n: int):
    rows = []
    for i in range(n):
        send_hour = ri(0, 23)
        active_hour = ri(7, 23)
        hour_match = abs(send_hour - active_hour) <= 2
        notif_type = rc(NOTIF_TYPES)
        follows = r() < 0.4
        fatigue = ri(0, 15)
        opened = 1 if hour_match and follows and fatigue < 8 and r() < 0.6 else (1 if r() < 0.15 else 0)
        rows.append({
            "user_id": f"seed_user_{ri(0, 500)}",
            "notification_type": notif_type,
            "send_hour": send_hour,
            "day_of_week": ri(0, 6),
            "notifications_received_today": fatigue,
            "creator_id": f"seed_creator_{ri(0, 200)}",
            "follows_creator": follows,
            "category": rc(CATEGORIES),
            "user_active_hour": active_hour,
            "label": opened,
        })
    return rows


# ─── SUBSCRIPTION PRICING ────────────────────────────────────────────────────

def seed_subscription(n: int):
    rows = []
    for i in range(n):
        device = rc(DEVICES)
        country = rc(COUNTRIES)
        watch = round(random.uniform(5, 300), 2)
        purchases = ri(0, 20)
        days = ri(1, 730)
        is_creator = r() < 0.2

        if watch > 120 and purchases > 3 and device == "ios":
            tier = rc(["pro", "creator"])
        elif watch > 60 or purchases > 1:
            tier = rc(["basic", "pro"])
        else:
            tier = "free"

        rows.append({
            "user_id": f"seed_user_{i}",
            "device_type": device,
            "country": country,
            "avg_daily_watch_minutes": watch,
            "past_in_app_purchases": purchases,
            "followed_creators_count": ri(0, 100),
            "days_on_platform": days,
            "is_creator": is_creator,
            "churn_risk_score": round(r(), 4),
            "current_tier": rc(TIERS),
            "label": tier,
        })
    return rows


# ─── RTB BIDDING ─────────────────────────────────────────────────────────────

def seed_rtb(n: int):
    rows = []
    for i in range(n):
        engagement = round(r(), 4)
        placement = ri(1, 3)
        hour = ri(0, 23)
        prime = 18 <= hour <= 22
        avg_winning = round(random.uniform(3, 25), 2)
        winning_bid = round(avg_winning * random.uniform(0.8, 1.3) * (1.3 if prime else 1.0) * (1 + engagement * 0.3), 2)
        rows.append({
            "impression_id": f"imp_{i}",
            "user_engagement_score": engagement,
            "placement_type": placement,
            "hour_of_day": hour,
            "day_of_week": ri(0, 6),
            "device_type": rc(DEVICES),
            "geo": rc(COUNTRIES),
            "avg_winning_bid": avg_winning,
            "historical_ctr": round(random.uniform(0.005, 0.08), 4),
            "historical_cvr": round(random.uniform(0.001, 0.02), 4),
            "label": winning_bid,
        })
    return rows


# ─── FRAUD DETECTION ─────────────────────────────────────────────────────────

def seed_fraud(n: int):
    rows = []
    for i in range(n):
        is_fraud = r() < 0.08
        rows.append({
            "event_id": f"evt_{i}",
            "user_id": f"seed_user_{ri(0, 500)}",
            "ip_address_hash": f"hash_{ri(0, 10000) if not is_fraud else ri(0, 50)}",
            "device_fingerprint": f"fp_{ri(0, 5000)}",
            "clicks_per_minute": round(random.uniform(50, 500) if is_fraud else random.uniform(0, 15), 2),
            "views_per_minute": round(random.uniform(100, 1000) if is_fraud else random.uniform(0, 10), 2),
            "account_age_days": ri(0, 3) if is_fraud else ri(10, 730),
            "vpn_detected": r() < 0.8 if is_fraud else r() < 0.05,
            "datacenter_ip": r() < 0.7 if is_fraud else r() < 0.02,
            "same_ip_accounts": ri(10, 100) if is_fraud else ri(1, 3),
            "label": 1 if is_fraud else 0,
        })
    return rows


# ─── CONTENT MODERATION ──────────────────────────────────────────────────────

def seed_moderation(n: int):
    rows = []
    labels = ["safe", "safe", "safe", "safe", "spam", "toxic", "nsfw"]
    for i in range(n):
        label = rc(labels)
        rows.append({
            "content_id": f"content_{i}",
            "content_type": rc(["comment", "video", "profile", "message"]),
            "text_toxicity_score": round(random.uniform(0.6, 1.0) if label == "toxic" else random.uniform(0, 0.3), 4),
            "has_url": r() < (0.7 if label == "spam" else 0.1),
            "has_phone": r() < (0.4 if label == "spam" else 0.02),
            "caps_ratio": round(random.uniform(0.5, 1.0) if label in ["spam", "toxic"] else random.uniform(0, 0.2), 4),
            "special_char_ratio": round(random.uniform(0.3, 0.8) if label == "spam" else random.uniform(0, 0.1), 4),
            "word_count": ri(1, 10) if label == "spam" else ri(5, 200),
            "prior_violations": ri(2, 10) if label != "safe" else ri(0, 1),
            "account_age_days": ri(0, 5) if label != "safe" else ri(30, 730),
            "label": label,
        })
    return rows


# ─── BRAND SAFETY ────────────────────────────────────────────────────────────

def seed_brand_safety(n: int):
    rows = []
    labels = ["safe", "safe", "safe", "restricted", "blocked"]
    for i in range(n):
        label = rc(labels)
        rows.append({
            "video_id": f"seed_video_{ri(0, 1000)}",
            "title_toxicity": round(random.uniform(0.5, 1.0) if label == "blocked" else random.uniform(0, 0.2), 4),
            "description_toxicity": round(random.uniform(0.4, 0.9) if label == "blocked" else random.uniform(0, 0.15), 4),
            "category": rc(CATEGORIES),
            "has_age_restriction": label in ["restricted", "blocked"],
            "prior_violations": ri(3, 10) if label != "safe" else ri(0, 1),
            "channel_trust_score": round(random.uniform(0.1, 0.4) if label != "safe" else random.uniform(0.6, 1.0), 4),
            "label": label,
        })
    return rows


# ─── ADVANCED TARGETING ──────────────────────────────────────────────────────

def seed_targeting(n: int):
    rows = []
    for i in range(n):
        converted = r() < 0.12
        rows.append({
            "user_id": f"seed_user_{ri(0, 500)}",
            "ad_id": f"ad_{ri(0, 200)}",
            "age_bucket": rc(["18-24", "25-34", "35-44", "45-54", "55+"]),
            "gender": rg(),
            "country": rc(COUNTRIES),
            "top_category": rc(CATEGORIES),
            "device_type": rc(DEVICES),
            "hour_of_day": ri(0, 23),
            "is_subscriber": r() < 0.3,
            "lifetime_value": round(random.uniform(0, 500), 2),
            "label": 1 if converted else 0,
        })
    return rows


# ─── ENGAGEMENT PREDICTOR ────────────────────────────────────────────────────

def seed_engagement(n: int):
    rows = []
    for i in range(n):
        subs = ri(100, 5000000)
        views = int(subs * random.uniform(0.01, 2.0))
        rows.append({
            "video_id": f"seed_video_{i}",
            "creator_id": f"seed_creator_{ri(0, 200)}",
            "title_length": ri(10, 100),
            "has_thumbnail": r() < 0.9,
            "duration_seconds": ri(30, 3600),
            "category": rc(CATEGORIES),
            "upload_hour": ri(0, 23),
            "creator_subscriber_count": subs,
            "creator_avg_views": round(subs * random.uniform(0.1, 0.5), 2),
            "label": round(views / max(subs, 1), 4),
        })
    return rows


# ─── VIRAL PREDICTION ────────────────────────────────────────────────────────

def seed_viral(n: int):
    rows = []
    for i in range(n):
        went_viral = r() < 0.05
        velocity = round(random.uniform(5, 100) if went_viral else random.uniform(0, 10), 4)
        rows.append({
            "video_id": f"seed_video_{i}",
            "views_1h": ri(1000, 50000) if went_viral else ri(0, 500),
            "views_6h": ri(50000, 500000) if went_viral else ri(0, 5000),
            "shares_1h": ri(500, 10000) if went_viral else ri(0, 50),
            "comments_1h": ri(200, 5000) if went_viral else ri(0, 20),
            "likes_1h": ri(1000, 20000) if went_viral else ri(0, 100),
            "velocity_score": velocity,
            "creator_subscriber_count": ri(1000, 10000000),
            "category": rc(CATEGORIES),
            "label": 1 if went_viral else 0,
        })
    return rows


# ─── LIFETIME VALUE ───────────────────────────────────────────────────────────

def seed_ltv(n: int):
    rows = []
    for i in range(n):
        months = ri(0, 24)
        tips = ri(0, 50)
        merch = ri(0, 10)
        spend = round(months * rc([4.99, 9.99, 19.99, 0]) + tips * random.uniform(1, 20) + merch * random.uniform(10, 50), 2)
        rows.append({
            "user_id": f"seed_user_{i}",
            "days_on_platform": ri(1, 730),
            "total_watch_minutes": round(random.uniform(0, 50000), 2),
            "total_spend": spend,
            "subscription_months": months,
            "tip_count": tips,
            "merch_purchases": merch,
            "device_type": rc(DEVICES),
            "country": rc(COUNTRIES),
            "label": round(spend * random.uniform(0.8, 1.5), 2),
        })
    return rows


SEEDERS = {
    "churn_training":                   seed_churn,
    "feed_personalization_training":    seed_feed,
    "search_ranking_training":          seed_search,
    "notification_optimizer_training":  seed_notifications,
    "subscription_pricing_training":    seed_subscription,
    "rtb_bidding_training":             seed_rtb,
    "fraud_detection_training":         seed_fraud,
    "content_moderation_training":      seed_moderation,
    "brand_safety_training":            seed_brand_safety,
    "advanced_targeting_training":      seed_targeting,
    "engagement_predictor_training":    seed_engagement,
    "viral_prediction_training":        seed_viral,
    "lifetime_value_training":          seed_ltv,
}


if __name__ == "__main__":
    print(f"Seeding training data (target: {TARGET_ROWS} rows per table)...\n")
    for table_name, seeder in SEEDERS.items():
        current = current_row_count(table_name)
        needed = max(TARGET_ROWS - current, 0)
        if needed == 0:
            print(f"  {table_name}: already has {current} rows, skipping")
            continue
        print(f"  {table_name}: {current} rows -> adding {needed}...")
        rows = seeder(needed)
        insert_rows(table(table_name), rows)

    print("\nVerifying final row counts:")
    for table_name in SEEDERS:
        count = current_row_count(table_name)
        status = "READY" if count >= 1000 else "NEEDS MORE"
        print(f"  {table_name}: {count} rows [{status}]")

    print("\nTraining data ready. Run 03_train_vertex_ai_models.py next.")
