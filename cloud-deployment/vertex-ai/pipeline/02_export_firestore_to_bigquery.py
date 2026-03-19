#!/usr/bin/env python3
"""
Step 2: Export real Firestore user/video/ad data into BigQuery training tables.
Pulls actual MyChannel data to train real Vertex AI models.
"""

import datetime
from google.cloud import firestore, bigquery

PROJECT_ID = "mychannel-ca26d"
DATASET_ID = "vertex_ai_training"

db = firestore.Client(project=PROJECT_ID)
bq = bigquery.Client(project=PROJECT_ID)


def table(name):
    return f"{PROJECT_ID}.{DATASET_ID}.{name}"


def insert_rows(table_id, rows):
    if not rows:
        print(f"  No rows to insert for {table_id}")
        return
    errors = bq.insert_rows_json(table_id, rows)
    if errors:
        print(f"  BQ insert errors for {table_id}: {errors[:3]}")
    else:
        print(f"  Inserted {len(rows)} rows into {table_id}")


# ─── CHURN TRAINING DATA ────────────────────────────────────────────────────

def export_churn_data():
    print("Exporting churn training data...")
    rows = []
    users = db.collection("users").limit(5000).stream()
    for doc in users:
        u = doc.to_dict()
        if not u:
            continue
        last_active = u.get("lastActiveAt")
        if isinstance(last_active, datetime.datetime):
            days_inactive = (datetime.datetime.utcnow() - last_active.replace(tzinfo=None)).days
        else:
            days_inactive = 30

        watch_7d = float(u.get("watchMinutes7d", 0))
        watch_prev_7d = float(u.get("watchMinutesPrev7d", watch_7d))
        change = ((watch_7d - watch_prev_7d) / max(watch_prev_7d, 1))

        rows.append({
            "user_id": doc.id,
            "days_since_last_active": days_inactive,
            "watch_time_change_7d": round(change, 4),
            "sessions_this_week": int(u.get("sessionsThisWeek", 0)),
            "sessions_last_week": int(u.get("sessionsLastWeek", 1)),
            "is_subscriber": bool(u.get("isPremium", False)),
            "notifications_disabled": not bool(u.get("notificationsEnabled", True)),
            "interactions_7d": int(u.get("interactions7d", 0)),
            "total_watch_minutes_30d": float(u.get("watchMinutes30d", 0)),
            "followed_creators_count": int(u.get("followingCount", 0)),
            "avg_session_minutes": float(u.get("avgSessionMinutes", 0)),
            "days_on_platform": int(u.get("daysOnPlatform", 0)),
            "label": 1 if days_inactive > 30 else 0,
        })
    insert_rows(table("churn_training"), rows)


# ─── FEED PERSONALIZATION TRAINING DATA ─────────────────────────────────────

def export_feed_data():
    print("Exporting feed personalization training data...")
    rows = []
    events = db.collection("videoWatchEvents").limit(10000).stream()
    for doc in events:
        e = doc.to_dict()
        if not e:
            continue
        rows.append({
            "user_id": e.get("userId", ""),
            "video_id": e.get("videoId", ""),
            "category": e.get("category", "general"),
            "creator_id": e.get("creatorId", ""),
            "hours_since_published": float(e.get("hoursSincePublished", 24)),
            "like_ratio": float(e.get("likeRatio", 0)),
            "is_trending": bool(e.get("isTrending", False)),
            "user_top_category_1": e.get("userTopCategory1", ""),
            "user_top_category_2": e.get("userTopCategory2", ""),
            "follows_creator": bool(e.get("followsCreator", False)),
            "user_avg_watch_pct": float(e.get("userAvgWatchPct", 0.5)),
            "label": float(e.get("watchPercentage", 0)),
        })
    insert_rows(table("feed_personalization_training"), rows)


# ─── SEARCH RANKING TRAINING DATA ───────────────────────────────────────────

def export_search_data():
    print("Exporting search ranking training data...")
    rows = []
    events = db.collection("searchEvents").limit(10000).stream()
    for doc in events:
        e = doc.to_dict()
        if not e:
            continue
        rows.append({
            "query": e.get("query", ""),
            "video_id": e.get("videoId", ""),
            "title_match_score": float(e.get("titleMatchScore", 0)),
            "tag_match_score": float(e.get("tagMatchScore", 0)),
            "view_count": int(e.get("viewCount", 0)),
            "like_ratio": float(e.get("likeRatio", 0)),
            "hours_since_published": float(e.get("hoursSincePublished", 720)),
            "is_trending": bool(e.get("isTrending", False)),
            "category_match": bool(e.get("categoryMatch", False)),
            "creator_followed": bool(e.get("creatorFollowed", False)),
            "label": int(e.get("wasClicked", 0)),
        })
    insert_rows(table("search_ranking_training"), rows)


# ─── NOTIFICATION OPTIMIZER TRAINING DATA ───────────────────────────────────

def export_notification_data():
    print("Exporting notification optimizer training data...")
    rows = []
    events = db.collection("notificationEvents").limit(10000).stream()
    for doc in events:
        e = doc.to_dict()
        if not e:
            continue
        rows.append({
            "user_id": e.get("userId", ""),
            "notification_type": e.get("type", "general"),
            "send_hour": int(e.get("sendHour", 12)),
            "day_of_week": int(e.get("dayOfWeek", 0)),
            "notifications_received_today": int(e.get("notificationsToday", 0)),
            "creator_id": e.get("creatorId", ""),
            "follows_creator": bool(e.get("followsCreator", False)),
            "category": e.get("category", "general"),
            "user_active_hour": int(e.get("userActiveHour", 19)),
            "label": int(e.get("wasOpened", 0)),
        })
    insert_rows(table("notification_optimizer_training"), rows)


# ─── SUBSCRIPTION PRICING TRAINING DATA ─────────────────────────────────────

def export_subscription_data():
    print("Exporting subscription pricing training data...")
    rows = []
    users = db.collection("users").limit(5000).stream()
    for doc in users:
        u = doc.to_dict()
        if not u:
            continue
        rows.append({
            "user_id": doc.id,
            "device_type": u.get("deviceType", "android"),
            "country": u.get("country", "US"),
            "avg_daily_watch_minutes": float(u.get("avgDailyWatchMinutes", 30)),
            "past_in_app_purchases": int(u.get("inAppPurchaseCount", 0)),
            "followed_creators_count": int(u.get("followingCount", 0)),
            "days_on_platform": int(u.get("daysOnPlatform", 0)),
            "is_creator": bool(u.get("isCreator", False)),
            "churn_risk_score": float(u.get("churnRiskScore", 0.3)),
            "current_tier": u.get("subscriptionTier", "free"),
            "label": u.get("subscriptionTier", "free"),
        })
    insert_rows(table("subscription_pricing_training"), rows)


# ─── RTB BIDDING TRAINING DATA ──────────────────────────────────────────────

def export_rtb_data():
    print("Exporting RTB bidding training data...")
    rows = []
    events = db.collection("adImpressions").limit(10000).stream()
    for doc in events:
        e = doc.to_dict()
        if not e:
            continue
        rows.append({
            "impression_id": doc.id,
            "user_engagement_score": float(e.get("userEngagementScore", 0.5)),
            "placement_type": int(e.get("placementType", 1)),
            "hour_of_day": int(e.get("hourOfDay", 12)),
            "day_of_week": int(e.get("dayOfWeek", 0)),
            "device_type": e.get("deviceType", "mobile"),
            "geo": e.get("geo", "US"),
            "avg_winning_bid": float(e.get("avgWinningBid", 10.0)),
            "historical_ctr": float(e.get("historicalCtr", 0.02)),
            "historical_cvr": float(e.get("historicalCvr", 0.005)),
            "label": float(e.get("winningBid", 10.0)),
        })
    insert_rows(table("rtb_bidding_training"), rows)


# ─── FRAUD DETECTION TRAINING DATA ──────────────────────────────────────────

def export_fraud_data():
    print("Exporting fraud detection training data...")
    rows = []
    events = db.collection("securityEvents").limit(10000).stream()
    for doc in events:
        e = doc.to_dict()
        if not e:
            continue
        rows.append({
            "event_id": doc.id,
            "user_id": e.get("userId", ""),
            "ip_address_hash": e.get("ipHash", ""),
            "device_fingerprint": e.get("deviceFingerprint", ""),
            "clicks_per_minute": float(e.get("clicksPerMinute", 0)),
            "views_per_minute": float(e.get("viewsPerMinute", 0)),
            "account_age_days": int(e.get("accountAgeDays", 0)),
            "vpn_detected": bool(e.get("vpnDetected", False)),
            "datacenter_ip": bool(e.get("datacenterIp", False)),
            "same_ip_accounts": int(e.get("sameIpAccounts", 1)),
            "label": int(e.get("isFraud", 0)),
        })
    insert_rows(table("fraud_detection_training"), rows)


# ─── CONTENT MODERATION TRAINING DATA ───────────────────────────────────────

def export_moderation_data():
    print("Exporting content moderation training data...")
    rows = []
    events = db.collection("moderationEvents").limit(10000).stream()
    for doc in events:
        e = doc.to_dict()
        if not e:
            continue
        rows.append({
            "content_id": doc.id,
            "content_type": e.get("contentType", "comment"),
            "text_toxicity_score": float(e.get("toxicityScore", 0)),
            "has_url": bool(e.get("hasUrl", False)),
            "has_phone": bool(e.get("hasPhone", False)),
            "caps_ratio": float(e.get("capsRatio", 0)),
            "special_char_ratio": float(e.get("specialCharRatio", 0)),
            "word_count": int(e.get("wordCount", 0)),
            "prior_violations": int(e.get("priorViolations", 0)),
            "account_age_days": int(e.get("accountAgeDays", 0)),
            "label": e.get("moderationLabel", "safe"),
        })
    insert_rows(table("content_moderation_training"), rows)


# ─── ENGAGEMENT PREDICTOR TRAINING DATA ─────────────────────────────────────

def export_engagement_data():
    print("Exporting engagement predictor training data...")
    rows = []
    videos = db.collection("videos").limit(5000).stream()
    for doc in videos:
        v = doc.to_dict()
        if not v:
            continue
        sub_count = int(v.get("creatorSubscriberCount", 1))
        view_count = int(v.get("viewCount", 0))
        rows.append({
            "video_id": doc.id,
            "creator_id": v.get("creatorId", ""),
            "title_length": len(v.get("title", "")),
            "has_thumbnail": bool(v.get("thumbnailUrl")),
            "duration_seconds": int(v.get("durationSeconds", 0)),
            "category": v.get("category", "general"),
            "upload_hour": int(v.get("uploadHour", 12)),
            "creator_subscriber_count": sub_count,
            "creator_avg_views": float(v.get("creatorAvgViews", 0)),
            "label": round(view_count / max(sub_count, 1), 4),
        })
    insert_rows(table("engagement_predictor_training"), rows)


# ─── VIRAL PREDICTION TRAINING DATA ─────────────────────────────────────────

def export_viral_data():
    print("Exporting viral prediction training data...")
    rows = []
    videos = db.collection("videos").limit(5000).stream()
    for doc in videos:
        v = doc.to_dict()
        if not v:
            continue
        views = int(v.get("viewCount", 0))
        rows.append({
            "video_id": doc.id,
            "views_1h": int(v.get("views1h", 0)),
            "views_6h": int(v.get("views6h", 0)),
            "shares_1h": int(v.get("shares1h", 0)),
            "comments_1h": int(v.get("comments1h", 0)),
            "likes_1h": int(v.get("likes1h", 0)),
            "velocity_score": float(v.get("velocityScore", 0)),
            "creator_subscriber_count": int(v.get("creatorSubscriberCount", 0)),
            "category": v.get("category", "general"),
            "label": 1 if views > 100000 else 0,
        })
    insert_rows(table("viral_prediction_training"), rows)


# ─── LIFETIME VALUE TRAINING DATA ───────────────────────────────────────────

def export_ltv_data():
    print("Exporting lifetime value training data...")
    rows = []
    users = db.collection("users").limit(5000).stream()
    for doc in users:
        u = doc.to_dict()
        if not u:
            continue
        rows.append({
            "user_id": doc.id,
            "days_on_platform": int(u.get("daysOnPlatform", 0)),
            "total_watch_minutes": float(u.get("totalWatchMinutes", 0)),
            "total_spend": float(u.get("totalSpend", 0)),
            "subscription_months": int(u.get("subscriptionMonths", 0)),
            "tip_count": int(u.get("tipCount", 0)),
            "merch_purchases": int(u.get("merchPurchases", 0)),
            "device_type": u.get("deviceType", "android"),
            "country": u.get("country", "US"),
            "label": float(u.get("ltv12m", 0)),
        })
    insert_rows(table("lifetime_value_training"), rows)


if __name__ == "__main__":
    print(f"Exporting Firestore data to BigQuery ({PROJECT_ID}.{DATASET_ID})...\n")
    export_churn_data()
    export_feed_data()
    export_search_data()
    export_notification_data()
    export_subscription_data()
    export_rtb_data()
    export_fraud_data()
    export_moderation_data()
    export_engagement_data()
    export_viral_data()
    export_ltv_data()
    print("\nAll Firestore data exported to BigQuery.")
