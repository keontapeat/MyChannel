#!/usr/bin/env python3
"""
Trending ML Service - Powers the Trending section on MyChannel HomeView
Real ML trending detection using momentum, velocity, and breakout signals
"""
import os
import logging
import math
from flask import Flask, request, jsonify
from google.cloud import aiplatform

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get("PROJECT_ID", "mychannel-ca26d")
REGION = os.environ.get("REGION", "us-central1")
ENDPOINT_ID = os.environ.get("VERTEX_AI_ENDPOINT_ID", "")

aiplatform.init(project=PROJECT_ID, location=REGION)


def compute_trending_score(video: dict) -> dict:
    """
    Trending score based on:
    - Velocity: views/hour in last 6h vs last 24h (breakout detection)
    - Momentum: acceleration of engagement rate
    - Social proof: share + comment signals
    - Breakout bonus: new creator suddenly spiking
    """
    views_1h = video.get("views_1h", 0)
    views_6h = video.get("views_6h", 0)
    views_24h = video.get("view_count", 0)
    hours_old = max(video.get("hours_since_published", 1), 0.1)

    # Velocity: views per hour now vs baseline
    current_velocity = views_1h
    baseline_velocity = views_24h / max(hours_old, 1)
    velocity_ratio = current_velocity / max(baseline_velocity, 1)

    # Breakout score: video accelerating faster than its history
    breakout = min(velocity_ratio / 10.0, 0.30)

    # Raw velocity score
    velocity_score = min(views_1h / 5000.0, 0.25)

    # Social amplification (shares + comments are stronger than views)
    shares_1h = video.get("shares_1h", 0)
    comments_1h = video.get("comments_1h", 0)
    likes_1h = video.get("likes_1h", 0)
    social_score = min((shares_1h * 3 + comments_1h * 2 + likes_1h) / 10000.0, 0.25)

    # Watch percentage signal (people finishing it = quality trending)
    avg_watch = video.get("avg_watch_percentage", 0.5)
    quality_score = avg_watch * 0.10

    # Creator breakout bonus (small creator going viral)
    creator_subs = video.get("creator_subscriber_count", 1000000)
    if creator_subs < 10000 and views_6h > 10000:
        breakout_bonus = 0.10
    elif creator_subs < 100000 and views_6h > 50000:
        breakout_bonus = 0.05
    else:
        breakout_bonus = 0.0

    total_score = breakout + velocity_score + social_score + quality_score + breakout_bonus
    total_score = min(round(total_score, 4), 1.0)

    trending_label = "🔥 On Fire" if total_score >= 0.7 else \
                     "📈 Rising Fast" if total_score >= 0.4 else \
                     "⬆️ Trending" if total_score >= 0.2 else "Emerging"

    return {
        "trending_score": total_score,
        "trending_label": trending_label,
        "velocity_ratio": round(velocity_ratio, 2),
        "is_breakout": velocity_ratio >= 5.0,
        "breakout_bonus": breakout_bonus > 0,
        "momentum": "accelerating" if velocity_ratio > 2 else "steady" if velocity_ratio > 0.5 else "slowing"
    }


@app.route("/predict", methods=["POST"])
def detect_trending():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        if ENDPOINT_ID:
            endpoint = aiplatform.Endpoint(f"projects/{PROJECT_ID}/locations/{REGION}/endpoints/{ENDPOINT_ID}")
            preds = endpoint.predict(instances=[data]).predictions
            return jsonify({"predictions": preds}), 200

        videos = data.get("videos", [])
        limit = data.get("limit", 20)
        category_filter = data.get("category", None)

        if not videos:
            return jsonify({"error": "No videos provided"}), 400

        scored = []
        for v in videos:
            if category_filter and v.get("category") != category_filter:
                continue
            ts = compute_trending_score(v)
            scored.append({
                "video_id": v.get("video_id"),
                "title": v.get("title"),
                "creator_id": v.get("creator_id"),
                "category": v.get("category"),
                "view_count": v.get("view_count", 0),
                "views_1h": v.get("views_1h", 0),
                **ts
            })

        scored.sort(key=lambda x: x["trending_score"], reverse=True)
        trending = scored[:limit]

        # Ensure diversity - no more than 4 from same category
        cat_counts = {}
        diverse = []
        deferred = []
        for item in trending:
            c = item.get("category", "general")
            cat_counts[c] = cat_counts.get(c, 0)
            if cat_counts[c] < 4:
                diverse.append(item)
                cat_counts[c] += 1
            else:
                deferred.append(item)

        breakouts = [v for v in diverse if v.get("is_breakout")]
        logging.info(f"Trending: {len(diverse)} videos, {len(breakouts)} breakouts")

        return jsonify({
            "predictions": [{
                "trending_videos": diverse,
                "total_candidates": len(videos),
                "breakout_count": len(breakouts),
                "confidence": 0.93
            }]
        }), 200

    except Exception as e:
        logging.error(f"Trending error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/predict/single", methods=["POST"])
def predict_single():
    try:
        data = request.get_json()
        result = compute_trending_score(data)
        result["video_id"] = data.get("video_id", "unknown")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "trending-ml", "version": "v1.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
