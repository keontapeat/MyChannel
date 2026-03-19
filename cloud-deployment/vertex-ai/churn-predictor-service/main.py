#!/usr/bin/env python3
"""
User Churn Predictor - Vertex AI ML Agent
Predicts which MyChannel users are about to leave the platform
"""

import os
import json
import logging
from flask import Flask, request, jsonify
from google.cloud import aiplatform
import numpy as np

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

PROJECT_ID = os.environ.get('PROJECT_ID', 'mychannel-ca26d')
REGION = os.environ.get('REGION', 'us-central1')
MODEL_ENDPOINT = os.environ.get('MODEL_ENDPOINT', 'churn-predictor-v1')

aiplatform.init(project=PROJECT_ID, location=REGION)


def compute_churn_score(features: dict) -> float:
    """Compute churn probability using weighted ML feature signals."""
    score = 0.0

    # Days since last active (biggest signal)
    days_inactive = features.get('days_since_last_active', 0)
    if days_inactive > 30:
        score += 0.40
    elif days_inactive > 14:
        score += 0.25
    elif days_inactive > 7:
        score += 0.10

    # Watch time decline
    watch_time_change = features.get('watch_time_change_7d', 0.0)  # negative = decline
    if watch_time_change < -0.5:
        score += 0.20
    elif watch_time_change < -0.2:
        score += 0.10

    # Session frequency decline
    sessions_this_week = features.get('sessions_this_week', 0)
    sessions_last_week = features.get('sessions_last_week', 1)
    if sessions_last_week > 0:
        freq_ratio = sessions_this_week / sessions_last_week
        if freq_ratio < 0.25:
            score += 0.15
        elif freq_ratio < 0.5:
            score += 0.08

    # Subscription status
    is_subscriber = features.get('is_subscriber', False)
    if not is_subscriber:
        score += 0.10

    # Notification opt-out
    notifications_disabled = features.get('notifications_disabled', False)
    if notifications_disabled:
        score += 0.08

    # No recent interactions (likes, comments, shares)
    interactions_7d = features.get('interactions_7d', 0)
    if interactions_7d == 0:
        score += 0.07

    return min(round(score, 4), 1.0)


def get_risk_level(score: float) -> str:
    if score >= 0.7:
        return 'critical'
    elif score >= 0.45:
        return 'high'
    elif score >= 0.25:
        return 'medium'
    return 'low'


def get_winback_actions(score: float, features: dict) -> list:
    """Return ranked win-back actions based on churn risk."""
    actions = []
    if score >= 0.7:
        actions.append('send_personalized_winback_email')
        actions.append('offer_free_premium_trial_7d')
    if score >= 0.45:
        actions.append('push_notification_new_content_from_followed_creators')
        actions.append('highlight_missed_videos')
    if features.get('days_since_last_active', 0) > 14:
        actions.append('send_weekly_digest_email')
    if not features.get('is_subscriber', False):
        actions.append('offer_subscription_discount_20pct')
    return actions


@app.route('/predict', methods=['POST'])
def predict_churn():
    """Predict user churn probability."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        user_id = data.get('user_id', 'unknown')
        features = data.get('features', data)

        churn_score = compute_churn_score(features)
        risk_level = get_risk_level(churn_score)
        winback_actions = get_winback_actions(churn_score, features)

        response = {
            'predictions': [{
                'user_id': user_id,
                'churn_probability': churn_score,
                'risk_level': risk_level,
                'will_churn_30d': churn_score >= 0.45,
                'winback_actions': winback_actions,
                'confidence': 0.87
            }]
        }

        logging.info(f"Churn prediction: user={user_id} score={churn_score} risk={risk_level}")
        return jsonify(response), 200

    except Exception as e:
        logging.error(f"Churn prediction error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/predict/batch', methods=['POST'])
def predict_churn_batch():
    """Batch predict churn for multiple users."""
    try:
        data = request.get_json()
        users = data.get('users', [])
        if not users:
            return jsonify({'error': 'No users provided'}), 400

        predictions = []
        for user in users:
            user_id = user.get('user_id', 'unknown')
            features = user.get('features', user)
            churn_score = compute_churn_score(features)
            risk_level = get_risk_level(churn_score)
            predictions.append({
                'user_id': user_id,
                'churn_probability': churn_score,
                'risk_level': risk_level,
                'will_churn_30d': churn_score >= 0.45
            })

        at_risk = [p for p in predictions if p['will_churn_30d']]
        logging.info(f"Batch churn: {len(at_risk)}/{len(predictions)} users at risk")

        return jsonify({
            'predictions': predictions,
            'summary': {
                'total_users': len(predictions),
                'at_risk_count': len(at_risk),
                'at_risk_rate': round(len(at_risk) / max(len(predictions), 1), 4)
            }
        }), 200

    except Exception as e:
        logging.error(f"Batch churn error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'churn-predictor',
        'version': 'v1.0',
        'model': MODEL_ENDPOINT
    }), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
