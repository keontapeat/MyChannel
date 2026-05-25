"""
Content Fatigue AI Service
Detect when user is tired of a topic and inject diversity
"""
import os
from flask import Flask, request, jsonify
from collections import Counter

app = Flask(__name__)

def detect_content_fatigue(watch_history: list, current_session: list) -> dict:
    if not watch_history:
        return {'fatigued': False, 'topics': [], 'diversityScore': 1.0, 'recommendation': 'show_normal_feed'}

    # Count topic exposure in recent history (last 20 videos)
    recent = watch_history[-20:]
    topic_counts = Counter()
    for video in recent:
        for tag in video.get('tags', []):
            topic_counts[tag.lower()] += 1
        category = video.get('category', '')
        if category:
            topic_counts[category.lower()] += 1

    total = sum(topic_counts.values())
    topic_ratios = {t: c / max(total, 1) for t, c in topic_counts.most_common(10)}

    # Fatigue detected if >50% same topic
    fatigued_topics = [t for t, r in topic_ratios.items() if r > 0.5]
    overexposed = [t for t, r in topic_ratios.items() if r > 0.3]

    # Session fatigue - same topic 3+ videos in a row
    session_topics = [v.get('category', '') for v in current_session[-5:]]
    consecutive_same = _max_consecutive(session_topics)
    session_fatigued = consecutive_same >= 3

    diversity_score = 1.0 - (len(overexposed) * 0.2)
    diversity_score = round(max(0.0, diversity_score), 3)

    is_fatigued = bool(fatigued_topics) or session_fatigued

    return {
        'fatigued': is_fatigued,
        'fatiguedTopics': fatigued_topics,
        'overexposedTopics': overexposed,
        'topicDistribution': topic_ratios,
        'diversityScore': diversity_score,
        'consecutiveSameCategory': consecutive_same,
        'recommendation': 'inject_diversity' if is_fatigued else 'show_normal_feed',
        'diversityTopics': _suggest_different_topics(overexposed)
    }

def _max_consecutive(items: list) -> int:
    if not items: return 0
    max_run, cur_run = 1, 1
    for i in range(1, len(items)):
        if items[i] == items[i-1] and items[i]:
            cur_run += 1
            max_run = max(max_run, cur_run)
        else:
            cur_run = 1
    return max_run

def _suggest_different_topics(overexposed: list) -> list:
    all_topics = ['gaming', 'cooking', 'music', 'sports', 'tech', 'travel', 'comedy', 'science', 'art', 'fitness']
    return [t for t in all_topics if t not in overexposed][:3]

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_content_fatigue(
        data.get('watchHistory', []),
        data.get('currentSession', [])
    )
    return jsonify({'userId': data.get('userId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'content-fatigue-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
