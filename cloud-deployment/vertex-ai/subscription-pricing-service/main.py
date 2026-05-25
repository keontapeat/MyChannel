#!/usr/bin/env python3
"""
Subscription Pricing Agent - Vertex AI ML Agent
Optimizes subscription tier pricing and personalized offers for MyChannel
"""

import os
import logging
from flask import Flask, request, jsonify
from google.cloud import aiplatform
import numpy as np

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get('PROJECT_ID', 'mychannel-ca26d')
REGION = os.environ.get('REGION', 'us-central1')
MODEL_ENDPOINT = os.environ.get('MODEL_ENDPOINT', 'subscription-pricing-v1')

aiplatform.init(project=PROJECT_ID, location=REGION)

# Base subscription tiers
SUBSCRIPTION_TIERS = {
    'free': {'price': 0.0, 'features': ['ads', 'sd_quality', 'basic_feed']},
    'basic': {'price': 4.99, 'features': ['no_ads', 'hd_quality', 'downloads_5']},
    'pro': {'price': 9.99, 'features': ['no_ads', '4k_quality', 'downloads_unlimited', 'early_access']},
    'creator': {'price': 19.99, 'features': ['no_ads', '4k_quality', 'downloads_unlimited', 'analytics', 'priority_support', 'creator_fund']}
}


def compute_price_elasticity(user_profile: dict) -> float:
    """Estimate user price sensitivity (0=very sensitive, 1=not sensitive)."""
    elasticity = 0.5

    # Income proxy signals
    device_type = user_profile.get('device_type', 'android')
    if device_type == 'ios':
        elasticity += 0.15  # iOS users typically higher income

    # Engagement depth
    avg_daily_minutes = user_profile.get('avg_daily_watch_minutes', 30)
    if avg_daily_minutes > 120:
        elasticity += 0.20
    elif avg_daily_minutes > 60:
        elasticity += 0.10

    # Historical purchase behavior
    past_purchases = user_profile.get('past_in_app_purchases', 0)
    if past_purchases > 5:
        elasticity += 0.15
    elif past_purchases > 0:
        elasticity += 0.08

    # Geographic pricing factor
    geo = user_profile.get('country', 'US')
    geo_multipliers = {'US': 0.10, 'CA': 0.08, 'GB': 0.08, 'AU': 0.06, 'IN': -0.15, 'BR': -0.10}
    elasticity += geo_multipliers.get(geo, 0.0)

    # Creator following depth
    followed_creators = len(user_profile.get('followed_creators', []))
    if followed_creators > 20:
        elasticity += 0.10

    return min(max(round(elasticity, 4), 0.0), 1.0)


def recommend_tier(user_profile: dict, elasticity: float) -> dict:
    """Recommend the best subscription tier for this user."""
    current_tier = user_profile.get('current_tier', 'free')
    avg_daily_minutes = user_profile.get('avg_daily_watch_minutes', 30)
    churn_risk = user_profile.get('churn_risk_score', 0.3)

    if current_tier == 'free':
        if avg_daily_minutes > 90 and elasticity > 0.5:
            recommended = 'pro'
        elif avg_daily_minutes > 45 or elasticity > 0.4:
            recommended = 'basic'
        else:
            recommended = 'free'
    elif current_tier == 'basic':
        if avg_daily_minutes > 120 and elasticity > 0.6:
            recommended = 'pro'
        elif user_profile.get('is_creator', False):
            recommended = 'creator'
        else:
            recommended = 'basic'
    else:
        recommended = current_tier

    return SUBSCRIPTION_TIERS.get(recommended, SUBSCRIPTION_TIERS['free']), recommended


def compute_personalized_discount(user_profile: dict, churn_risk: float, elasticity: float) -> dict:
    """Compute personalized discount offer if applicable."""
    discount_pct = 0
    offer_reason = None

    # High churn risk - retention discount
    if churn_risk >= 0.6:
        discount_pct = 30
        offer_reason = 'retention_winback'
    elif churn_risk >= 0.4:
        discount_pct = 20
        offer_reason = 'retention_at_risk'

    # New user trial conversion
    days_on_platform = user_profile.get('days_on_platform', 0)
    if days_on_platform <= 7 and user_profile.get('current_tier') == 'free':
        discount_pct = max(discount_pct, 50)
        offer_reason = 'new_user_trial_conversion'

    # Price sensitive users
    if elasticity < 0.3 and discount_pct == 0:
        discount_pct = 15
        offer_reason = 'price_sensitive_user'

    return {
        'discount_percentage': discount_pct,
        'offer_reason': offer_reason,
        'has_offer': discount_pct > 0
    }


@app.route('/predict', methods=['POST'])
def optimize_pricing():
    """Recommend optimal pricing and tier for a user."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        user_id = data.get('user_id', 'unknown')
        user_profile = data.get('user_profile', data)
        churn_risk = user_profile.get('churn_risk_score', 0.3)

        elasticity = compute_price_elasticity(user_profile)
        tier_details, recommended_tier = recommend_tier(user_profile, elasticity)
        discount = compute_personalized_discount(user_profile, churn_risk, elasticity)

        base_price = tier_details['price']
        final_price = round(base_price * (1 - discount['discount_percentage'] / 100), 2)

        response = {
            'predictions': [{
                'user_id': user_id,
                'recommended_tier': recommended_tier,
                'base_price': base_price,
                'final_price': final_price,
                'discount': discount,
                'price_elasticity': elasticity,
                'tier_features': tier_details['features'],
                'upgrade_likelihood': round(elasticity * 0.8, 4),
                'confidence': 0.86
            }]
        }

        logging.info(f"Pricing optimized: user={user_id} tier={recommended_tier} price=${final_price}")
        return jsonify(response), 200

    except Exception as e:
        logging.error(f"Subscription pricing error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/predict/batch', methods=['POST'])
def optimize_pricing_batch():
    """Batch optimize pricing for multiple users."""
    try:
        data = request.get_json()
        users = data.get('users', [])
        if not users:
            return jsonify({'error': 'No users provided'}), 400

        results = []
        upgrade_candidates = 0
        for user in users:
            user_id = user.get('user_id', 'unknown')
            user_profile = user.get('profile', user)
            churn_risk = user_profile.get('churn_risk_score', 0.3)
            elasticity = compute_price_elasticity(user_profile)
            tier_details, recommended_tier = recommend_tier(user_profile, elasticity)
            discount = compute_personalized_discount(user_profile, churn_risk, elasticity)
            final_price = round(tier_details['price'] * (1 - discount['discount_percentage'] / 100), 2)
            should_upgrade = recommended_tier != user_profile.get('current_tier', 'free')
            if should_upgrade:
                upgrade_candidates += 1
            results.append({
                'user_id': user_id,
                'recommended_tier': recommended_tier,
                'final_price': final_price,
                'has_discount_offer': discount['has_offer'],
                'upgrade_recommended': should_upgrade
            })

        return jsonify({
            'predictions': results,
            'summary': {
                'total_users': len(users),
                'upgrade_candidates': upgrade_candidates,
                'users_with_offers': sum(1 for r in results if r['has_discount_offer'])
            }
        }), 200

    except Exception as e:
        logging.error(f"Batch pricing error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'subscription-pricing',
        'version': 'v1.0',
        'model': MODEL_ENDPOINT
    }), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
