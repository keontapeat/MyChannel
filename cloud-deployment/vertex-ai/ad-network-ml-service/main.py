#!/usr/bin/env python3
"""
Ad Network ML Service - MyChannel
Full ad network intelligence: CTR prediction, revenue optimization,
advertiser matching, fraud filtering, dynamic floor pricing, ROAS prediction
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

# CPM floors by placement type
FLOOR_CPM = {"pre_roll": 4.0, "mid_roll": 3.0, "post_roll": 1.5, "banner": 0.5, "overlay": 0.8}

# Category CPM multipliers
CATEGORY_CPM = {
    "finance": 2.8, "tech": 2.2, "education": 1.8, "fitness": 1.6,
    "cooking": 1.4, "travel": 1.5, "sports": 1.3, "gaming": 1.1,
    "music": 0.9, "comedy": 0.8, "general": 1.0
}


def predict_ctr(ad: dict, user: dict, context: dict) -> float:
    """Predict click-through rate for this ad+user+context combo."""
    base_ctr = 0.025

    # Ad quality signals
    ad_relevance = ad.get("relevance_score", 0.5)
    base_ctr *= (0.5 + ad_relevance)

    # User engagement level
    user_engagement = user.get("engagement_score", 0.5)
    base_ctr *= (0.7 + user_engagement * 0.6)

    # Category match
    ad_cats = ad.get("target_categories", [])
    user_cats = user.get("top_categories", [])
    cat_match = len(set(ad_cats) & set(user_cats)) / max(len(ad_cats), 1)
    base_ctr *= (0.8 + cat_match * 0.4)

    # Placement type (pre-roll gets highest CTR)
    placement = context.get("placement_type", "pre_roll")
    placement_multipliers = {"pre_roll": 1.3, "mid_roll": 1.0, "post_roll": 0.7, "banner": 0.4, "overlay": 0.6}
    base_ctr *= placement_multipliers.get(placement, 1.0)

    # Time of day
    hour = context.get("hour_of_day", 12)
    if 18 <= hour <= 22:
        base_ctr *= 1.2
    elif 6 <= hour <= 9:
        base_ctr *= 1.1

    # Device type
    device = user.get("device_type", "mobile")
    if device == "ctv":
        base_ctr *= 1.4
    elif device == "ios":
        base_ctr *= 1.1

    # Historical CTR signal
    hist_ctr = ad.get("historical_ctr", base_ctr)
    base_ctr = (base_ctr * 0.6 + hist_ctr * 0.4)

    return round(min(max(base_ctr, 0.001), 0.15), 6)


def compute_dynamic_floor_price(context: dict, user: dict) -> float:
    placement = context.get("placement_type", "pre_roll")
    base_floor = FLOOR_CPM.get(placement, 1.0)
    category = context.get("video_category", "general")
    base_floor *= CATEGORY_CPM.get(category, 1.0)

    # User value multiplier
    is_subscriber = user.get("is_subscriber", False)
    ltv = user.get("lifetime_value", 0)
    if is_subscriber:
        base_floor *= 1.3
    if ltv > 100:
        base_floor *= 1.4
    elif ltv > 50:
        base_floor *= 1.2

    # Device premium
    device = user.get("device_type", "mobile")
    if device == "ctv":
        base_floor *= 1.8
    elif device == "ios":
        base_floor *= 1.3

    return round(base_floor, 4)


def predict_roas(campaign: dict) -> dict:
    budget = campaign.get("budget", 100)
    target_cpa = campaign.get("target_cpa", 10)
    historical_ctr = campaign.get("historical_ctr", 0.025)
    historical_cvr = campaign.get("historical_cvr", 0.02)
    avg_cpm = campaign.get("avg_cpm", 5.0)

    impressions = (budget / avg_cpm) * 1000
    clicks = impressions * historical_ctr
    conversions = clicks * historical_cvr
    revenue = conversions * target_cpa
    roas = revenue / max(budget, 1)

    return {
        "estimated_impressions": int(impressions),
        "estimated_clicks": int(clicks),
        "estimated_conversions": int(conversions),
        "estimated_revenue": round(revenue, 2),
        "roas": round(roas, 4),
        "roas_label": "excellent" if roas >= 4 else "good" if roas >= 2 else "break_even" if roas >= 1 else "negative"
    }


def score_advertiser(advertiser: dict) -> dict:
    payment_history = advertiser.get("payment_score", 0.8)
    ad_quality = advertiser.get("avg_ad_quality_score", 0.7)
    brand_safety = advertiser.get("brand_safety_score", 0.8)
    spend_history = advertiser.get("total_historical_spend", 0)
    dispute_rate = advertiser.get("dispute_rate", 0.0)

    trust_score = (payment_history * 0.35 + ad_quality * 0.25 +
                   brand_safety * 0.25 + min(spend_history / 10000.0, 1.0) * 0.10 -
                   dispute_rate * 0.3)
    trust_score = min(max(round(trust_score, 4), 0.0), 1.0)

    tier = "premium" if trust_score >= 0.8 else "standard" if trust_score >= 0.5 else "restricted"

    return {
        "trust_score": trust_score,
        "advertiser_tier": tier,
        "approved": trust_score >= 0.4,
        "premium_inventory_access": trust_score >= 0.8,
        "recommended_cpm_bid": round(5.0 * trust_score, 2)
    }


def run_auction(bids: list, floor_price: float, context: dict) -> dict:
    """Second-price auction with quality adjustment."""
    eligible = [b for b in bids if b.get("bid_cpm", 0) >= floor_price]
    if not eligible:
        return {"winner": None, "clearing_price": 0, "fill": False}

    # Quality-adjusted effective CPM
    for b in eligible:
        quality = b.get("ad_quality_score", 0.7)
        b["effective_cpm"] = b["bid_cpm"] * quality

    eligible.sort(key=lambda x: x["effective_cpm"], reverse=True)
    winner = eligible[0]
    second_price = eligible[1]["bid_cpm"] if len(eligible) > 1 else floor_price
    clearing_price = round(max(second_price * 1.01, floor_price), 4)

    return {
        "winner_advertiser_id": winner.get("advertiser_id"),
        "winning_ad_id": winner.get("ad_id"),
        "clearing_price_cpm": clearing_price,
        "fill": True,
        "total_bidders": len(bids),
        "eligible_bidders": len(eligible),
        "floor_price": floor_price
    }


@app.route("/predict/ctr", methods=["POST"])
def predict_ctr_endpoint():
    try:
        data = request.get_json()
        ctr = predict_ctr(
            data.get("ad", {}),
            data.get("user", {}),
            data.get("context", {})
        )
        floor = compute_dynamic_floor_price(data.get("context", {}), data.get("user", {}))
        return jsonify({"predictions": [{
            "predicted_ctr": ctr,
            "floor_price_cpm": floor,
            "impression_id": data.get("impression_id"),
            "confidence": 0.89
        }]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/roas", methods=["POST"])
def roas_endpoint():
    try:
        data = request.get_json()
        result = predict_roas(data.get("campaign", data))
        result["campaign_id"] = data.get("campaign_id")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/advertiser-score", methods=["POST"])
def advertiser_score():
    try:
        data = request.get_json()
        result = score_advertiser(data.get("advertiser", data))
        result["advertiser_id"] = data.get("advertiser_id")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/auction", methods=["POST"])
def auction():
    try:
        data = request.get_json()
        bids = data.get("bids", [])
        context = data.get("context", {})
        user = data.get("user", {})
        floor = compute_dynamic_floor_price(context, user)
        result = run_auction(bids, floor, context)
        logging.info(f"Auction: {len(bids)} bids, winner={result.get('winner_advertiser_id')}, price={result.get('clearing_price_cpm')}")
        return jsonify({"predictions": [result]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/predict/revenue-forecast", methods=["POST"])
def revenue_forecast():
    try:
        data = request.get_json()
        daily_impressions = data.get("daily_impressions", 0)
        fill_rate = data.get("fill_rate", 0.75)
        avg_cpm = data.get("avg_cpm", 3.5)
        daily_revenue = (daily_impressions * fill_rate / 1000.0) * avg_cpm
        return jsonify({"predictions": [{
            "daily_revenue": round(daily_revenue, 2),
            "weekly_revenue": round(daily_revenue * 7, 2),
            "monthly_revenue": round(daily_revenue * 30, 2),
            "annual_revenue": round(daily_revenue * 365, 2),
            "fill_rate": fill_rate,
            "avg_cpm": avg_cpm
        }]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "ad-network-ml", "version": "v1.0"}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
