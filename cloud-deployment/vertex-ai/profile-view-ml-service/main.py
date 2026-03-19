#!/usr/bin/env python3
"""
Profile View ML Service - MyChannel
Powers ProfileView: creator score, audience insights, content recommendations,
growth predictions, collab matching, monetization potential
"""
import os
import logging
from flask import Flask, request, jsonify
from google.cloud import aiplatform

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get("PROJECT_ID", "mychannel-ca26d")
REGION = os.environ.get("REGION", "us-central1")
ENDPOINT_ID = os.environ.get("VERTEX_AI_ENDPOINT_ID", "")

aiplatform.init(project=PROJECT_ID, location=REGION)


def compute_creator_score(creator: dict) -> dict:
    score = 0.0
    subscribers = creator.get("subscriber_count", 0)
    avg_views = creator.get("avg_views_per_video", 0)
    upload_frequency = creator.get("uploads_per_month", 0)
    avg_watch_pct = creator.get("avg_watch_percentage", 0.5)
    engagement_rate = creator.get("engagement_rate", 0.03)
    account_age_days = creator.get("account_age_days", 30)

    # Reach score
    score += min(subscribers / 1_000_000.0, 1.0) * 0.20
    # View velocity
    score += min(avg_views / 100_000.0, 1.0) * 0.20
    # Consistency
    score += min(upload_frequency / 12.0, 1.0) * 0.15
    # Content quality
    score += avg_watch_pct * 0.20
    # Engagement
    score += min(engagement_rate / 0.1, 1.0) * 0.15
    # Longevity
    score += min(account_age_days / 730.0, 1.0) * 0.10

    score = min(round(score, 4), 1.0)

    if score >= 0.85:
        tier = "Elite Creator"
    elif score >= 0.65:
        tier = "Top Creator"
    elif score >= 0.45:
        tier = "Rising Creator"
    elif score >= 0.25:
        tier = "Growing Creator"
    else:
        tier = "New Creator"

    return {"creator_score": score, "creator_tier": tier}


def predict_subscriber_growth(creator: dict) -> dict:
    current_subs = creator.get("subscriber_count", 0)
    growth_rate_30d = creator.get("subscriber_growth_rate_30d", 0.02)
    upload_freq = creator.get("uploads_per_month", 2)
    avg_views = creator.get("avg_views_per_video", 0)
    engagement_rate = creator.get("engagement_rate", 0.03)

    # Base growth velocity
    velocity = growth_rate_30d * (1 + min(upload_freq / 10.0, 0.5))
    velocity *= (1 + min(engagement_rate / 0.05, 0.3))

    growth_30d = int(current_subs * velocity)
    growth_90d = int(current_subs * velocity * 3.2)
    growth_180d = int(current_subs * velocity * 7.0)

    milestone = None
    milestones = [1000, 5000, 10000, 50000, 100000, 500000, 1000000]
    for m in milestones:
        if current_subs < m:
            days_to_milestone = int((m - current_subs) / max(growth_30d / 30.0, 1))
            milestone = {"target": m, "estimated_days": days_to_milestone}
            break

    return {
        "growth_30d": growth_30d,
        "growth_90d": growth_90d,
        "growth_180d": growth_180d,
        "next_milestone": milestone,
        "growth_trajectory": "accelerating" if velocity > growth_rate_30d else "steady"
    }


def compute_monetization_potential(creator: dict) -> dict:
    subscribers = creator.get("subscriber_count", 0)
    avg_views = creator.get("avg_views_per_video", 0)
    avg_watch_pct = creator.get("avg_watch_percentage", 0.5)
    engagement_rate = creator.get("engagement_rate", 0.03)
    niche = creator.get("primary_category", "general")

    # CPM by niche
    niche_cpm = {
        "tech": 8.0, "finance": 12.0, "education": 6.0, "gaming": 3.5,
        "fitness": 5.0, "cooking": 4.0, "music": 2.5, "comedy": 2.0,
        "sports": 4.5, "travel": 5.5, "general": 3.0
    }
    cpm = niche_cpm.get(niche, 3.0)

    # Monthly ad revenue estimate
    monetizable_views = avg_views * 4 * avg_watch_pct  # 4 uploads/month avg
    monthly_ad_revenue = (monetizable_views / 1000.0) * cpm

    # Super chat / tip potential
    tip_potential = subscribers * engagement_rate * 0.01 * 5.0  # avg $5 tip

    # Sponsorship potential
    if subscribers >= 100000:
        sponsorship = subscribers * 0.01  # $0.01 per sub
    elif subscribers >= 10000:
        sponsorship = subscribers * 0.005
    else:
        sponsorship = 0

    total_monthly = round(monthly_ad_revenue + tip_potential + sponsorship, 2)

    return {
        "estimated_monthly_revenue": total_monthly,
        "ad_revenue_estimate": round(monthly_ad_revenue, 2),
        "tip_revenue_estimate": round(tip_potential, 2),
        "sponsorship_estimate": round(sponsorship, 2),
        "monetization_tier": "high" if total_monthly > 5000 else "medium" if total_monthly > 500 else "growing"
    }


def find_collab_matches(creator: dict, candidate_creators: list) -> list:
    creator_cats = creator.get("top_categories", [])
    creator_subs = creator.get("subscriber_count", 1)
    matches = []
    for c in candidate_creators:
        if c.get("creator_id") == creator.get("creator_id"):
            continue
        # Category overlap
        shared_cats = set(creator_cats) & set(c.get("top_categories", []))
        cat_score = len(shared_cats) / max(len(creator_cats), 1)
        # Sub ratio (best collabs are within 10x)
        sub_ratio = min(creator_subs, c.get("subscriber_count", 1)) / max(creator_subs, c.get("subscriber_count", 1))
        # Audience overlap (simplified)
        collab_score = round(cat_score * 0.5 + sub_ratio * 0.3 + c.get("engagement_rate", 0.03) * 2, 4)
        matches.append({
            "creator_id": c.get("creator_id"),
            "display_name": c.get("display_name"),
            "subscriber_count": c.get("subscriber_count"),
            "shared_categories": list(shared_cats),
            "collab_score": collab_score,
            "estimated_reach_boost": round(sub_ratio * 0.3, 4)
        })
    matches.sort(key=lambda x: x["collab_score"], reverse=True)
    return matches[:10]


@app.route("/predict/creator-score", methods=["POST"])
def creator_score():
    try:
        data = request.get_json()
        creator = data.get("creator", data)
        score = compute_creator_score(creator)
        growth = predict_subscriber_growth(creator)
        monetization = compute_monetization_potential(creator)
        return jsonify({"predictions": [{
            "creator_id": data.get("creator_id", "unknown"),
            **score, **growth, **monetization, "confidence": 0.87
        }]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/growth", methods=["POST"])
def growth():
    try:
        data = request.get_json()
        result = predict_subscriber_growth(data.get("creator", data))
        result["creator_id"] = data.get("creator_id", "unknown")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/collab-matches", methods=["POST"])
def collab_matches():
    try:
        data = request.get_json()
        creator = data.get("creator", {})
        candidates = data.get("candidate_creators", [])
        matches = find_collab_matches(creator, candidates)
        return jsonify({"predictions": [{"matches": matches, "total": len(matches)}]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/audience-insights", methods=["POST"])
def audience_insights():
    try:
        data = request.get_json()
        creator = data.get("creator", data)
        subscribers = creator.get("subscriber_count", 0)
        engagement_rate = creator.get("engagement_rate", 0.03)
        top_cats = creator.get("top_categories", [])
        geo_split = creator.get("geo_split", {"US": 0.4, "other": 0.6})
        return jsonify({"predictions": [{
            "creator_id": data.get("creator_id"),
            "estimated_active_fans": int(subscribers * engagement_rate * 10),
            "top_categories": top_cats,
            "geo_distribution": geo_split,
            "best_upload_times": [{"day": "Saturday", "hour": 14}, {"day": "Sunday", "hour": 11}],
            "audience_retention_health": "strong" if creator.get("avg_watch_percentage", 0) > 0.5 else "needs_improvement"
        }]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "profile-view-ml", "version": "v1.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
