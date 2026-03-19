"""
Synthetic Training Data Generator for all 190+ MyChannel Vertex AI models.
Generates realistic training datasets and uploads them to BigQuery.
"""
import numpy as np
import pandas as pd
from google.cloud import bigquery
import json

PROJECT = "mychannel-ca26d"
DATASET = "vertex_ai_training"
client = bigquery.Client(project=PROJECT)

def upload_to_bq(df: pd.DataFrame, table_id: str):
    ref = f"{PROJECT}.{DATASET}.{table_id}"
    job = client.load_table_from_dataframe(df, ref,
        job_config=bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE"))
    job.result()
    print(f"[✓] {table_id}: {len(df)} rows uploaded")

def gen_viral_prediction(n=100000):
    np.random.seed(1)
    df = pd.DataFrame({
        "views_first_hour": np.random.exponential(500, n).astype(int),
        "likes_first_hour": np.random.exponential(50, n).astype(int),
        "shares_first_hour": np.random.exponential(20, n).astype(int),
        "comments_first_hour": np.random.exponential(30, n).astype(int),
        "ctr": np.random.beta(2, 8, n),
        "avg_watch_pct": np.random.beta(4, 3, n),
        "thumbnail_score": np.random.beta(5, 3, n),
        "title_length": np.random.randint(10, 100, n),
        "has_hashtags": np.random.randint(0, 2, n),
        "creator_subscriber_count": np.random.exponential(10000, n).astype(int),
        "creator_avg_views": np.random.exponential(5000, n).astype(int),
        "upload_hour": np.random.randint(0, 24, n),
        "upload_day_of_week": np.random.randint(0, 7, n),
        "video_duration_seconds": np.random.randint(30, 3600, n),
        "category_encoded": np.random.randint(0, 20, n),
    })
    score = (0.25 * np.log1p(df["views_first_hour"]) / 10 +
             0.2 * df["avg_watch_pct"] + 0.2 * df["thumbnail_score"] +
             0.15 * df["ctr"] * 10 + 0.2 * np.log1p(df["creator_subscriber_count"]) / 15)
    df["went_viral"] = (score + np.random.normal(0, 0.1, n) > 0.6).astype(int)
    return df

def gen_watch_time(n=100000):
    np.random.seed(2)
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
                       0.2 * df["hook_score"] + 0.1 * df["follows_creator"] +
                       0.1 * df["is_trending"] + np.random.normal(0, 0.05, n)).clip(0, 1)
    return df

def gen_trending_ml(n=100000):
    np.random.seed(3)
    df = pd.DataFrame({
        "velocity_1h": np.random.exponential(100, n),
        "velocity_24h": np.random.exponential(1000, n),
        "share_rate": np.random.beta(2, 10, n),
        "comment_rate": np.random.beta(2, 8, n),
        "like_rate": np.random.beta(5, 5, n),
        "recency_hours": np.random.exponential(12, n),
        "category_encoded": np.random.randint(0, 20, n),
        "region_encoded": np.random.randint(0, 50, n),
        "creator_tier": np.random.randint(0, 5, n),
        "seasonal_boost": np.random.beta(2, 5, n),
    })
    score = (0.3 * df["velocity_1h"] / 200 + 0.2 * df["like_rate"] +
             0.2 * df["share_rate"] * 5 + 0.15 * df["comment_rate"] * 5 +
             0.15 * df["seasonal_boost"])
    df["is_trending"] = (score + np.random.normal(0, 0.05, n) > 0.5).astype(int)
    return df

def gen_churn(n=100000):
    np.random.seed(4)
    df = pd.DataFrame({
        "days_since_last_active": np.random.exponential(10, n),
        "session_count_30d": np.random.poisson(15, n),
        "avg_session_duration": np.random.exponential(20, n),
        "videos_watched_30d": np.random.poisson(30, n),
        "likes_given_30d": np.random.poisson(10, n),
        "comments_30d": np.random.poisson(3, n),
        "subscription_age_days": np.random.exponential(180, n),
        "paid_subscriber": np.random.randint(0, 2, n),
        "notifications_clicked_pct": np.random.beta(3, 5, n),
        "creator_followed_count": np.random.poisson(8, n),
        "watch_time_minutes_30d": np.random.exponential(300, n),
    })
    risk = (0.3 * (df["days_since_last_active"] > 14).astype(int) +
            0.2 * (df["session_count_30d"] < 5).astype(int) +
            0.2 * (df["videos_watched_30d"] < 10).astype(int) +
            0.3 * (df["watch_time_minutes_30d"] < 60).astype(int))
    df["churned"] = (risk + np.random.normal(0, 0.1, n) > 0.5).astype(int)
    return df

def gen_spam_detection(n=100000):
    np.random.seed(5)
    df = pd.DataFrame({
        "post_frequency_per_hour": np.random.exponential(2, n),
        "duplicate_content_ratio": np.random.beta(2, 8, n),
        "account_age_days": np.random.exponential(365, n),
        "follower_following_ratio": np.random.exponential(1, n),
        "link_count": np.random.poisson(1, n),
        "caps_ratio": np.random.beta(2, 8, n),
        "emoji_count": np.random.poisson(2, n),
        "reported_count": np.random.poisson(0.5, n),
        "profile_pic_set": np.random.randint(0, 2, n),
        "verified": np.random.randint(0, 2, n),
        "device_fingerprint_unique": np.random.randint(0, 2, n),
    })
    risk = (0.3 * (df["post_frequency_per_hour"] > 10).astype(int) +
            0.2 * df["duplicate_content_ratio"] * 5 +
            0.2 * (df["account_age_days"] < 7).astype(int) +
            0.3 * (df["reported_count"] > 2).astype(int))
    df["is_spam"] = (risk + np.random.normal(0, 0.1, n) > 0.5).astype(int)
    return df

def gen_recommendations(n=100000):
    np.random.seed(6)
    df = pd.DataFrame({
        "user_category_affinity": np.random.beta(4, 3, n),
        "creator_affinity": np.random.beta(3, 4, n),
        "collaborative_score": np.random.beta(4, 3, n),
        "content_freshness": np.random.exponential(0.5, n).clip(0, 1),
        "diversity_score": np.random.beta(5, 5, n),
        "trending_boost": np.random.beta(2, 8, n),
        "watch_history_match": np.random.beta(4, 3, n),
        "liked_similar_pct": np.random.beta(3, 4, n),
        "completion_rate_similar": np.random.beta(4, 3, n),
        "user_session_depth": np.random.randint(1, 20, n),
    })
    score = (0.25 * df["user_category_affinity"] + 0.2 * df["creator_affinity"] +
             0.2 * df["collaborative_score"] + 0.1 * df["content_freshness"] +
             0.15 * df["watch_history_match"] + 0.1 * df["trending_boost"])
    df["label"] = (score + np.random.normal(0, 0.05, n) > 0.55).astype(int)
    return df

def gen_sentiment_analysis(n=100000):
    np.random.seed(7)
    df = pd.DataFrame({
        "positive_word_count": np.random.poisson(5, n),
        "negative_word_count": np.random.poisson(2, n),
        "exclamation_count": np.random.poisson(1, n),
        "question_count": np.random.poisson(1, n),
        "emoji_sentiment": np.random.uniform(-1, 1, n),
        "text_length": np.random.randint(1, 500, n),
        "caps_ratio": np.random.beta(2, 8, n),
        "profanity_count": np.random.poisson(0.2, n),
        "url_count": np.random.poisson(0.3, n),
        "mention_count": np.random.poisson(0.5, n),
    })
    score = (df["positive_word_count"] - df["negative_word_count"] * 2 +
             df["emoji_sentiment"] * 3 - df["profanity_count"] * 3 +
             df["exclamation_count"] * 0.5)
    df["sentiment"] = np.where(score > 2, 2, np.where(score < -1, 0, 1))  # 0=neg, 1=neutral, 2=pos
    return df

def gen_rtb_bidding(n=100000):
    np.random.seed(8)
    df = pd.DataFrame({
        "user_age_days": np.random.exponential(365, n),
        "user_ltv": np.random.exponential(50, n),
        "content_category": np.random.randint(0, 20, n),
        "ad_format": np.random.randint(0, 5, n),
        "device_type": np.random.randint(0, 4, n),
        "os": np.random.randint(0, 3, n),
        "hour_of_day": np.random.randint(0, 24, n),
        "day_of_week": np.random.randint(0, 7, n),
        "creator_cpm_history": np.random.exponential(3, n),
        "user_ad_clicks_30d": np.random.poisson(2, n),
        "page_ctr": np.random.beta(2, 10, n),
        "viewability_score": np.random.beta(7, 3, n),
        "audience_segment_size": np.random.exponential(100000, n).astype(int),
    })
    df["winning_bid_cpm"] = (2 + 0.00001 * df["user_ltv"] * 100 +
                              df["viewability_score"] * 3 +
                              df["page_ctr"] * 20 +
                              np.random.normal(0, 0.5, n)).clip(0.5, 20)
    return df

def gen_subscription_pricing(n=100000):
    np.random.seed(9)
    df = pd.DataFrame({
        "user_age_days": np.random.exponential(365, n),
        "watch_time_hours_30d": np.random.exponential(20, n),
        "videos_watched_30d": np.random.poisson(30, n),
        "creator_count_followed": np.random.poisson(8, n),
        "country": np.random.randint(0, 50, n),
        "subscription_tier": np.random.randint(0, 4, n),
        "prev_subscription_price": np.random.choice([0, 4.99, 9.99, 14.99], n),
        "ltv_estimate": np.random.exponential(100, n),
        "churn_risk_score": np.random.beta(3, 7, n),
        "engagement_score": np.random.beta(5, 3, n),
        "payment_method": np.random.randint(0, 5, n),
        "income_proxy": np.random.exponential(50000, n),
    })
    df["optimal_price"] = (4.99 + df["engagement_score"] * 10 +
                            df["ltv_estimate"] * 0.01 -
                            df["churn_risk_score"] * 5 +
                            np.random.normal(0, 0.5, n)).clip(0.99, 29.99)
    return df

def gen_search_ranking(n=100000):
    np.random.seed(10)
    df = pd.DataFrame({
        "query_match_score": np.random.beta(4, 3, n),
        "title_match_score": np.random.beta(4, 3, n),
        "description_match_score": np.random.beta(3, 4, n),
        "tag_match_score": np.random.beta(3, 4, n),
        "view_count": np.random.exponential(10000, n).astype(int),
        "like_ratio": np.random.beta(5, 2, n),
        "avg_watch_pct": np.random.beta(4, 3, n),
        "recency_score": np.random.beta(3, 5, n),
        "creator_authority_score": np.random.beta(4, 3, n),
        "engagement_rate": np.random.beta(3, 7, n),
        "ctr_from_search": np.random.beta(2, 8, n),
        "content_type": np.random.randint(0, 5, n),
        "language": np.random.randint(0, 30, n),
        "video_duration_seconds": np.random.randint(30, 3600, n),
    })
    df["relevance_score"] = (0.3 * df["query_match_score"] + 0.2 * df["title_match_score"] +
                              0.1 * df["description_match_score"] + 0.1 * df["tag_match_score"] +
                              0.1 * df["like_ratio"] + 0.1 * df["avg_watch_pct"] +
                              0.1 * df["creator_authority_score"] + np.random.normal(0, 0.03, n)).clip(0, 1)
    return df

def gen_ad_quality(n=100000):
    np.random.seed(11)
    df = pd.DataFrame({
        "resolution_score": np.random.beta(7, 3, n),
        "audio_quality_score": np.random.beta(6, 4, n),
        "ctr_history": np.random.beta(2, 8, n),
        "completion_rate": np.random.beta(4, 3, n),
        "brand_safety_score": np.random.beta(8, 2, n),
        "relevance_score": np.random.beta(5, 3, n),
        "ad_format_encoded": np.random.randint(0, 5, n),
        "landing_page_score": np.random.beta(6, 4, n),
        "frequency_cap_ok": np.random.randint(0, 2, n),
        "policy_violations": np.random.poisson(0.1, n),
    })
    df["quality_score"] = (0.15 * df["resolution_score"] + 0.15 * df["audio_quality_score"] +
                            0.2 * df["ctr_history"] * 5 + 0.15 * df["completion_rate"] +
                            0.15 * df["brand_safety_score"] + 0.2 * df["relevance_score"] -
                            0.5 * df["policy_violations"] + np.random.normal(0, 0.03, n)).clip(0, 1)
    return df

def gen_creator_studio_ml(n=100000):
    np.random.seed(12)
    df = pd.DataFrame({
        "video_count": np.random.poisson(50, n),
        "avg_views": np.random.exponential(5000, n),
        "subscriber_count": np.random.exponential(1000, n).astype(int),
        "upload_frequency_per_week": np.random.exponential(2, n),
        "avg_like_ratio": np.random.beta(5, 2, n),
        "avg_comment_rate": np.random.beta(2, 8, n),
        "revenue_30d": np.random.exponential(100, n),
        "watch_time_hours_30d": np.random.exponential(500, n),
        "subscriber_growth_rate": np.random.normal(0.02, 0.05, n),
        "content_consistency_score": np.random.beta(5, 3, n),
        "best_upload_hour": np.random.randint(0, 24, n),
    })
    df["growth_potential_score"] = (0.2 * df["avg_like_ratio"] +
                                     0.2 * df["content_consistency_score"] +
                                     0.2 * (df["subscriber_growth_rate"].clip(0, 0.5) / 0.5) +
                                     0.2 * df["avg_comment_rate"] * 5 +
                                     0.2 * (df["upload_frequency_per_week"].clip(0, 5) / 5) +
                                     np.random.normal(0, 0.05, n)).clip(0, 1)
    return df

def gen_profile_view_ml(n=100000):
    np.random.seed(13)
    df = pd.DataFrame({
        "profile_views_7d": np.random.poisson(50, n),
        "profile_views_30d": np.random.poisson(200, n),
        "subscriber_conversion_rate": np.random.beta(2, 8, n),
        "bio_completeness": np.random.beta(7, 3, n),
        "avatar_quality": np.random.beta(6, 4, n),
        "verified": np.random.randint(0, 2, n),
        "social_links_count": np.random.randint(0, 5, n),
        "featured_video_views": np.random.exponential(1000, n),
        "search_appearance_count": np.random.poisson(20, n),
        "recommendation_appearance_count": np.random.poisson(100, n),
    })
    df["subscribe_probability"] = (0.2 * df["subscriber_conversion_rate"] +
                                    0.15 * df["bio_completeness"] +
                                    0.15 * df["avatar_quality"] +
                                    0.1 * df["verified"] +
                                    0.2 * (df["profile_views_7d"] / 100).clip(0, 1) +
                                    0.2 * df["social_links_count"] / 5 +
                                    np.random.normal(0, 0.03, n)).clip(0, 1)
    return df

def gen_thumbnail_generator(n=100000):
    np.random.seed(14)
    df = pd.DataFrame({
        "face_count": np.random.randint(0, 4, n),
        "text_overlay": np.random.randint(0, 2, n),
        "brightness_score": np.random.beta(6, 4, n),
        "contrast_score": np.random.beta(5, 5, n),
        "color_saturation": np.random.beta(5, 4, n),
        "rule_of_thirds_score": np.random.beta(5, 5, n),
        "emotion_detected": np.random.randint(0, 6, n),
        "category_encoded": np.random.randint(0, 20, n),
        "a_b_test_winner_history": np.random.beta(4, 4, n),
        "mobile_clarity_score": np.random.beta(7, 3, n),
    })
    df["ctr_prediction"] = (0.15 * (df["face_count"] > 0).astype(int) +
                             0.1 * df["text_overlay"] * 0.3 +
                             0.15 * df["brightness_score"] +
                             0.15 * df["contrast_score"] +
                             0.15 * df["rule_of_thirds_score"] +
                             0.15 * df["mobile_clarity_score"] +
                             0.15 * df["a_b_test_winner_history"] +
                             np.random.normal(0, 0.02, n)).clip(0, 1)
    return df

def gen_top_rank_ml(n=100000):
    np.random.seed(15)
    df = pd.DataFrame({
        "total_views": np.random.exponential(100000, n).astype(int),
        "total_watch_hours": np.random.exponential(5000, n),
        "subscriber_count": np.random.exponential(10000, n).astype(int),
        "avg_like_ratio": np.random.beta(5, 2, n),
        "revenue_per_view": np.random.exponential(0.001, n),
        "comment_rate": np.random.beta(2, 8, n),
        "share_rate": np.random.beta(2, 10, n),
        "consistency_score": np.random.beta(5, 3, n),
        "growth_velocity": np.random.exponential(0.05, n),
        "community_score": np.random.beta(5, 3, n),
        "category_encoded": np.random.randint(0, 20, n),
    })
    df["rank_score"] = (0.2 * np.log1p(df["total_views"]) / 15 +
                        0.15 * df["avg_like_ratio"] +
                        0.15 * df["consistency_score"] +
                        0.1 * df["growth_velocity"].clip(0, 1) +
                        0.1 * df["community_score"] +
                        0.15 * df["comment_rate"] * 5 +
                        0.15 * np.log1p(df["subscriber_count"]) / 15 +
                        np.random.normal(0, 0.03, n)).clip(0, 1)
    return df

TABLES = {
    "viral_prediction_training": gen_viral_prediction,
    "watch_time_predictor_training": gen_watch_time,
    "trending_ml_training": gen_trending_ml,
    "spam_detection_training": gen_spam_detection,
    "recommendations_training": gen_recommendations,
    "sentiment_analysis_training": gen_sentiment_analysis,
    "ad_quality_training": gen_ad_quality,
    "creator_studio_ml_training": gen_creator_studio_ml,
    "profile_view_ml_training": gen_profile_view_ml,
    "thumbnail_generator_training": gen_thumbnail_generator,
    "top_rank_ml_training": gen_top_rank_ml,
    "rtb_bidding_training": gen_rtb_bidding,
    "subscription_pricing_training": gen_subscription_pricing,
    "search_ranking_training": gen_search_ranking,
}

if __name__ == "__main__":
    print(f"[*] Generating and uploading {len(TABLES)} synthetic training datasets...")
    for table_id, gen_fn in TABLES.items():
        print(f"[*] Generating {table_id}...")
        df = gen_fn()
        upload_to_bq(df, table_id)
    print(f"\n[✓] All {len(TABLES)} datasets uploaded to BigQuery!")
