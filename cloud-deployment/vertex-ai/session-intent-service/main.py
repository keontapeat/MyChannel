"""
Session Intent AI Service
Detect what user wants THIS session - smarter feed
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

INTENT_PROFILES = {
    'entertainment': {'description': 'Casual browsing for fun', 'feedMix': {'trending': 0.4, 'recommended': 0.4, 'new': 0.2}},
    'learning': {'description': 'Wants to learn something', 'feedMix': {'tutorials': 0.5, 'educational': 0.3, 'recommended': 0.2}},
    'background': {'description': 'Background noise/ambient', 'feedMix': {'music': 0.4, 'ambient': 0.3, 'lofi': 0.3}},
    'catch_up': {'description': 'Catching up on subscriptions', 'feedMix': {'subscriptions': 0.7, 'recommended': 0.2, 'trending': 0.1}},
    'discovery': {'description': 'Wants to find new creators', 'feedMix': {'new_creators': 0.5, 'trending': 0.3, 'recommended': 0.2}},
    'news': {'description': 'Looking for current events', 'feedMix': {'news': 0.6, 'trending': 0.3, 'recommended': 0.1}},
    'sports': {'description': 'Sports highlights/content', 'feedMix': {'sports': 0.6, 'trending': 0.3, 'recommended': 0.1}},
}

def detect_session_intent(session_data: dict) -> dict:
    first_search = session_data.get('firstSearch', '')
    first_video_category = session_data.get('firstVideoCategory', '')
    time_of_day = session_data.get('timeOfDay', 12)
    day_of_week = session_data.get('dayOfWeek', 0)
    entry_point = session_data.get('entryPoint', 'home')  # home/search/notification/link
    device_type = session_data.get('deviceType', 'mobile')
    prev_session_intent = session_data.get('prevSessionIntent', '')

    intent_scores = {intent: 0.0 for intent in INTENT_PROFILES}

    # Entry point signals
    if entry_point == 'search':
        intent_scores['learning'] += 0.3
        intent_scores['news'] += 0.2
    elif entry_point == 'notification':
        intent_scores['catch_up'] += 0.4
    elif entry_point == 'home':
        intent_scores['entertainment'] += 0.3

    # Time signals
    if 7 <= time_of_day <= 9:  # Morning commute
        intent_scores['news'] += 0.3
        intent_scores['background'] += 0.2
    elif 12 <= time_of_day <= 13:  # Lunch
        intent_scores['entertainment'] += 0.3
        intent_scores['news'] += 0.2
    elif 17 <= time_of_day <= 19:  # After work
        intent_scores['entertainment'] += 0.3
        intent_scores['sports'] += 0.2
    elif 20 <= time_of_day <= 23:  # Evening
        intent_scores['entertainment'] += 0.2
        intent_scores['catch_up'] += 0.3

    # Day of week
    if day_of_week in [5, 6]:  # Weekend
        intent_scores['entertainment'] += 0.2
        intent_scores['learning'] += 0.2
        intent_scores['discovery'] += 0.1

    # First action signals
    search_lower = first_search.lower() if first_search else ''
    if any(w in search_lower for w in ['how to', 'tutorial', 'learn', 'guide']):
        intent_scores['learning'] += 0.5
    if any(w in search_lower for w in ['news', 'breaking', 'today', 'latest']):
        intent_scores['news'] += 0.5
    if any(w in search_lower for w in ['score', 'highlights', 'game', 'match']):
        intent_scores['sports'] += 0.5

    # Category signals
    cat_map = {
        'Education': 'learning', 'News': 'news', 'Sports': 'sports',
        'Music': 'background', 'Gaming': 'entertainment'
    }
    if first_video_category in cat_map:
        intent_scores[cat_map[first_video_category]] += 0.4

    # Momentum from prev session
    if prev_session_intent and prev_session_intent in intent_scores:
        intent_scores[prev_session_intent] += 0.1

    top_intent = max(intent_scores, key=intent_scores.get)
    confidence = min(intent_scores[top_intent] / 1.2, 1.0)

    return {
        'intent': top_intent,
        'confidence': round(confidence, 3),
        'intentProfile': INTENT_PROFILES[top_intent],
        'intentScores': {k: round(v, 3) for k, v in sorted(intent_scores.items(), key=lambda x: x[1], reverse=True)},
        'feedConfiguration': INTENT_PROFILES[top_intent]['feedMix'],
        'autoplayEnabled': top_intent in ['entertainment', 'background', 'catch_up']
    }

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_session_intent(data.get('sessionData', {}))
    return jsonify({'userId': data.get('userId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'session-intent-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
