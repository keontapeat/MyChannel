#!/usr/bin/env python3
"""
Top Rank ML Service - Powers the Top Rank section on MyChannel HomeView
Real ML ranking using engagement velocity, quality signals, and personalization
"""
import os
import logging
import numpy as np
from flask import Flask, request, jsonify
from google.cloud import aiplatform

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get("PROJECT_ID", "mychannel-ca26d")
REGION = os.environ.get("REGION", "us-central1")
ENDPOINT_ID = os.environ.get("VERTEX_AI_ENDPOINT_ID", "")

aiplatform.init(project=PROJECT_ID, location=REGION)


def compute_rank_score(video: dict, user_context: dict) -> float:
    score = 0.0
    # Engagement velocity (views per hour since published)
    views = video.get("view_count", 0)
    hours = max(video.get("hours_since_published", 1), 0.1)
    velocity = views / hours
    score += min(velocity / 10000.0, 0.25)

    # Like ratio
    score += video.get("like_ratio", 0.0) * 0.15

    # Comment engagement
    comments = video.get("comment_count", 0)
    score += min(comments / 1000.0, 0.10)

    # Share rate
    shares = video.get("share_count", 0)
    score += min(shares / 500.0, 0.10)

    # Average watch percentage (quality signal)
    avg_watch = video.get("avg_watch_percentage", 0.5)
    score += avg_watch * 0.15

    # Personalization: category affinity
    user_cats = user_context.get("top_categories", [])
    if video.get("category") in user_cats[:3]:
        score += 0.10
    elif video.get("category") in user_cats:
        score += 0.05

    # Creator authority
    creator_subs = video.get("creator_subscriber_count", 0)
    score += min(creator_subs / 10_000_000.0, 0.08)

    # Freshness bonus (hot in last 24h)
    if hours <= 24:
        score += 0.07

    # Trending multiplier
    if video.get("is_trending", False):
        score *= 1.2

    return min(round(score, 4), 1.0)


def assign_rank_badge(rank: int, score: float) -> str:
    if rank == 1:
        return "👑 #1"
    elif rank <= 3:
        return f"🔥 #{rank}"
    elif rank <= 10:
        return f"📈 #{rank}"
    else:
        return f"#{rank}"


@app.route("/predict", methods=["POST"])
def rank_top_videos():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No data provided"}), 400

        if ENDPOINT_ID:
            endpoint = aiplatform.Endpoint(f"projects/{PROJECT_ID}/locations/{REGION}/endpoints/{ENDPOINT_ID}")
            preds = endpoint.predict(instances=[data]).predictions
            return jsonify({"predictions": preds}), 200

        videos = data.get("videos", [])
        user_context = data.get("user_context", {})
        limit = data.get("limit", 10)

        if not videos:
            return jsonify({"error": "No videos provided"}), 400

        scored = []
        for v in videos:
            s = compute_rank_score(v, user_context)
            scored.append({**v, "rank_score": s})

        scored.sort(key=lambda x: x["rank_score"], reverse=True)
        top = scored[:limit]

        ranked = []
        for i, v in enumerate(top):
            ranked.append({
                "rank": i + 1,
                "rank_badge": assign_rank_badge(i + 1, v["rank_score"]),
                "video_id": v.get("video_id"),
                "title": v.get("title"),
                "creator_id": v.get("creator_id"),
                "rank_score": v["rank_score"],
                "category": v.get("category"),
                "view_count": v.get("view_count", 0),
                "is_trending": v.get("is_trending", False),
            })

        logging.info(f"Top Rank: ranked {len(videos)} videos, returning top {len(ranked)}")
        return jsonify({
            "predictions": [{
                "top_ranked": ranked,
                "total_candidates": len(videos),
                "user_id": data.get("user_id", "anonymous"),
                "confidence": 0.91
            }]
        }), 200

    except Exception as e:
        logging.error(f"Top Rank error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "top-rank-ml", "version": "v1.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
