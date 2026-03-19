"""
Creator Fan Matcher AI Service
Match creators with their superfans for loyalty programs
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def calculate_fan_score(user_activity: dict, creator_id: str) -> dict:
    watch_count = user_activity.get('watchCount', 0)
    total_watch_time_hours = user_activity.get('totalWatchTimeHours', 0)
    comment_count = user_activity.get('commentCount', 0)
    like_count = user_activity.get('likeCount', 0)
    share_count = user_activity.get('shareCount', 0)
    is_subscribed = user_activity.get('isSubscribed', False)
    is_member = user_activity.get('isMember', False)
    tip_count = user_activity.get('tipCount', 0)
    tip_total_usd = user_activity.get('tipTotalUsd', 0.0)
    notification_enabled = user_activity.get('notificationsEnabled', False)
    merch_purchases = user_activity.get('merchPurchases', 0)
    attendance_streak_days = user_activity.get('attendanceStreakDays', 0)
    first_watcher_count = user_activity.get('firstWatcherCount', 0)  # how often watches within 1hr of upload

    score = 0.0

    # Subscription & membership (baseline)
    if is_member: score += 20
    elif is_subscribed: score += 10

    # Watch time (most important signal)
    score += min(total_watch_time_hours * 2, 25)

    # Watch count
    score += min(watch_count * 0.5, 10)

    # Engagement
    score += min(comment_count * 0.5, 8)
    score += min(like_count * 0.2, 5)
    score += min(share_count * 1.0, 8)

    # Notifications + early watcher
    if notification_enabled: score += 3
    score += min(first_watcher_count * 0.5, 5)

    # Financial support
    score += min(tip_total_usd * 0.5, 15)
    score += min(merch_purchases * 3, 10)

    # Loyalty streak
    score += min(attendance_streak_days * 0.1, 5)

    score = min(round(score, 1), 100.0)

    tier = 'superfan' if score >= 70 else 'loyal' if score >= 40 else 'regular' if score >= 15 else 'casual'

    perks = _get_tier_perks(tier)

    return {
        'creatorId': creator_id,
        'fanScore': score,
        'fanTier': tier,
        'perks': perks,
        'scoreBreakdown': {
            'subscription': 20 if is_member else 10 if is_subscribed else 0,
            'watchTime': min(total_watch_time_hours * 2, 25),
            'engagement': min(comment_count * 0.5 + like_count * 0.2 + share_count, 21),
            'financial': min(tip_total_usd * 0.5 + merch_purchases * 3, 25),
            'loyalty': min(attendance_streak_days * 0.1, 5)
        },
        'reachOut': tier in ['superfan', 'loyal'],
        'suggestedAction': _get_action(tier)
    }

def _get_tier_perks(tier: str) -> list:
    perks = {
        'superfan': ['Early access to videos', 'Custom badge', 'Creator shoutout', 'Direct message access', 'Exclusive content'],
        'loyal': ['Loyalty badge', 'Priority comments', 'Members-only posts'],
        'regular': ['Regular badge', 'Comment highlight'],
        'casual': []
    }
    return perks.get(tier, [])

def _get_action(tier: str) -> str:
    actions = {
        'superfan': 'Send personal thank-you message + exclusive perk',
        'loyal': 'Invite to members community',
        'regular': 'Send engagement prompt',
        'casual': 'No action needed'
    }
    return actions.get(tier, 'No action')

@app.route('/score', methods=['POST'])
def score():
    data = request.json
    result = calculate_fan_score(
        data.get('userActivity', {}),
        data.get('creatorId', '')
    )
    return jsonify({'userId': data.get('userId', ''), **result})

@app.route('/top-fans', methods=['POST'])
def top_fans():
    data = request.json
    fans = data.get('fans', [])
    creator_id = data.get('creatorId', '')
    scored = [
        {'userId': f['userId'], **calculate_fan_score(f.get('activity', {}), creator_id)}
        for f in fans
    ]
    scored.sort(key=lambda x: x['fanScore'], reverse=True)
    superfans = [f for f in scored if f['fanTier'] == 'superfan']
    return jsonify({'creatorId': creator_id, 'topFans': scored[:20], 'superfanCount': len(superfans)})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'creator-fan-matcher'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
