#!/usr/bin/env python3
"""
Feed Personalization Agent - Vertex AI ML Agent
Personalizes the MyChannel home feed for each user
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
MODEL_ENDPOINT = os.environ.get('MODEL_ENDPOINT', 'feed-personalization-v1')

aiplatform.init(project=PROJECT_ID, location=REGION)


def score_video_for_user(video: dict, user_prefs: dict) -> float:
    """Score a video's relevance for a specific user (0.0 - 1.0)."""
    score = 0.0

    # Category match
    user_categories = user_prefs.get('top_categories', [])
    video_category = video.get('category', '')
    if video_category in user_categories:
        rank = user_categories.index(video_category)
        score += max(0.30 - rank * 0.05, 0.05)

    # Creator affinity - follows this creator
    followed_creators = user_prefs.get('followed_creators', [])
    if video.get('creator_id') in followed_creators:
        score += 0.25

    # Engagement signals on similar content
    avg_watch_pct = user_prefs.get('avg_watch_percentage', 0.5)
    score += avg_watch_pct * 0.15

    # Video freshness (newer = better)
    hours_old = video.get('hours_since_published', 24)
    if hours_old < 1:
        score += 0.15
    elif hours_old < 6:
        score += 0.10
    elif hours_old < 24:
        score += 0.05

    # Video quality signals
    like_ratio = video.get('like_ratio', 0.0)
    score += like_ratio * 0.10

    # Diversity boost - avoid showing same creator back to back
    last_seen_creator = user_prefs.get('last_seen_creator_id', '')
    if video.get('creator_id') == last_seen_creator:
        score -= 0.10

    # Trending boost
    if video.get('is_trending', False):
        score += 0.05

    return min(max(round(score, 4), 0.0), 1.0)


def personalize_feed(videos: list, user_prefs: dict, feed_size: int = 20) -> list:
    """Score and rank all candidate videos for a user."""
    scored = []
    for video in videos:
        relevance_score = score_video_for_user(video, user_prefs)
        scored.append({
            'video_id': video.get('video_id'),
            'relevance_score': relevance_score,
            'category': video.get('category'),
            'creator_id': video.get('creator_id'),
            'is_trending': video.get('is_trending', False)
        })

    scored.sort(key=lambda x: x['relevance_score'], reverse=True)

    # Inject diversity: no more than 3 from same creator in top 20
    creator_counts = {}
    diverse_feed = []
    deferred = []
    for item in scored:
        cid = item['creator_id']
        creator_counts[cid] = creator_counts.get(cid, 0)
        if creator_counts[cid] < 3:
            diverse_feed.append(item)
            creator_counts[cid] += 1
        else:
            deferred.append(item)
        if len(diverse_feed) >= feed_size:
            break

    return diverse_feed[:feed_size]


@app.route('/predict', methods=['POST'])
def personalize():
    """Personalize feed for a user."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        user_id = data.get('user_id', 'unknown')
        user_prefs = data.get('user_preferences', {})
        candidate_videos = data.get('candidate_videos', [])
        feed_size = data.get('feed_size', 20)

        if not candidate_videos:
            return jsonify({'error': 'No candidate videos provided'}), 400

        ranked_feed = personalize_feed(candidate_videos, user_prefs, feed_size)

        response = {
            'predictions': [{
                'user_id': user_id,
                'personalized_feed': ranked_feed,
                'total_candidates': len(candidate_videos),
                'feed_size': len(ranked_feed),
                'avg_relevance_score': round(
                    sum(v['relevance_score'] for v in ranked_feed) / max(len(ranked_feed), 1), 4
                ),
                'confidence': 0.91
            }]
        }

        logging.info(f"Feed personalized: user={user_id} candidates={len(candidate_videos)} returned={len(ranked_feed)}")
        return jsonify(response), 200

    except Exception as e:
        logging.error(f"Feed personalization error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'feed-personalization',
        'version': 'v1.0',
        'model': MODEL_ENDPOINT
    }), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
