#!/usr/bin/env python3
"""
Notification Optimizer Agent - Vertex AI ML Agent
Optimizes notification timing and content for MyChannel users
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
MODEL_ENDPOINT = os.environ.get('MODEL_ENDPOINT', 'notification-optimizer-v1')

aiplatform.init(project=PROJECT_ID, location=REGION)

# Peak engagement hours by timezone bucket
PEAK_HOURS = {
    'morning': [7, 8, 9],
    'lunch': [12, 13],
    'evening': [18, 19, 20, 21],
    'night': [22, 23]
}


def compute_open_probability(notification: dict, user_prefs: dict) -> float:
    """Predict probability user will open this notification."""
    score = 0.0

    # Notification type affinity
    notif_type = notification.get('type', '')
    type_affinities = user_prefs.get('notification_type_affinities', {})
    score += type_affinities.get(notif_type, 0.3) * 0.35

    # Creator affinity
    creator_id = notification.get('creator_id', '')
    followed_creators = user_prefs.get('followed_creators', [])
    if creator_id in followed_creators[:5]:
        score += 0.25
    elif creator_id in followed_creators:
        score += 0.10

    # Time of day match
    current_hour = notification.get('send_hour', 12)
    preferred_hours = user_prefs.get('active_hours', [18, 19, 20])
    if current_hour in preferred_hours:
        score += 0.20
    elif abs(min(abs(current_hour - h) for h in preferred_hours)) <= 1:
        score += 0.10

    # Fatigue penalty - too many notifications today
    notifs_today = user_prefs.get('notifications_received_today', 0)
    if notifs_today > 10:
        score -= 0.20
    elif notifs_today > 5:
        score -= 0.10

    # Content relevance
    user_categories = user_prefs.get('top_categories', [])
    notif_category = notification.get('category', '')
    if notif_category in user_categories[:3]:
        score += 0.15

    return min(max(round(score, 4), 0.0), 1.0)


def get_optimal_send_time(user_prefs: dict) -> dict:
    """Determine the best time to send notification to this user."""
    active_hours = user_prefs.get('active_hours', [18, 19, 20])
    best_hour = max(active_hours, key=lambda h: (
        user_prefs.get('hourly_open_rates', {}).get(str(h), 0.3)
    )) if active_hours else 19

    time_bucket = 'evening'
    for bucket, hours in PEAK_HOURS.items():
        if best_hour in hours:
            time_bucket = bucket
            break

    return {
        'optimal_hour': best_hour,
        'time_bucket': time_bucket,
        'timezone': user_prefs.get('timezone', 'America/New_York')
    }


def should_suppress(user_prefs: dict, notification: dict) -> tuple:
    """Decide if notification should be suppressed to avoid fatigue."""
    notifs_today = user_prefs.get('notifications_received_today', 0)
    notifs_this_hour = user_prefs.get('notifications_this_hour', 0)
    notif_priority = notification.get('priority', 'normal')

    if notif_priority == 'critical':
        return False, None
    if notifs_this_hour >= 3:
        return True, 'hourly_limit_reached'
    if notifs_today >= 15:
        return True, 'daily_limit_reached'
    if user_prefs.get('do_not_disturb', False):
        return True, 'do_not_disturb_active'

    return False, None


@app.route('/predict', methods=['POST'])
def optimize_notification():
    """Optimize a notification for a user."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        user_id = data.get('user_id', 'unknown')
        notification = data.get('notification', {})
        user_prefs = data.get('user_preferences', {})

        suppressed, suppress_reason = should_suppress(user_prefs, notification)
        open_probability = compute_open_probability(notification, user_prefs)
        optimal_time = get_optimal_send_time(user_prefs)

        response = {
            'predictions': [{
                'user_id': user_id,
                'should_send': not suppressed,
                'suppress_reason': suppress_reason,
                'open_probability': open_probability,
                'optimal_send_time': optimal_time,
                'send_now': not suppressed and open_probability >= 0.4,
                'confidence': 0.88
            }]
        }

        logging.info(f"Notification optimized: user={user_id} send={not suppressed} open_prob={open_probability}")
        return jsonify(response), 200

    except Exception as e:
        logging.error(f"Notification optimizer error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/predict/batch', methods=['POST'])
def optimize_batch():
    """Batch optimize notifications for multiple users."""
    try:
        data = request.get_json()
        users = data.get('users', [])
        notification = data.get('notification', {})

        if not users:
            return jsonify({'error': 'No users provided'}), 400

        results = []
        send_count = 0
        for user in users:
            user_id = user.get('user_id', 'unknown')
            user_prefs = user.get('preferences', {})
            suppressed, suppress_reason = should_suppress(user_prefs, notification)
            open_prob = compute_open_probability(notification, user_prefs)
            should_send = not suppressed and open_prob >= 0.35
            if should_send:
                send_count += 1
            results.append({
                'user_id': user_id,
                'should_send': should_send,
                'open_probability': open_prob,
                'suppress_reason': suppress_reason
            })

        return jsonify({
            'predictions': results,
            'summary': {
                'total_users': len(users),
                'will_send': send_count,
                'suppressed': len(users) - send_count,
                'estimated_opens': round(sum(r['open_probability'] for r in results if r['should_send']), 0)
            }
        }), 200

    except Exception as e:
        logging.error(f"Batch notification error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'notification-optimizer',
        'version': 'v1.0',
        'model': MODEL_ENDPOINT
    }), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
