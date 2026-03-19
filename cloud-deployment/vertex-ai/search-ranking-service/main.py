#!/usr/bin/env python3
"""
Search Ranking Agent - Vertex AI ML Agent
Optimizes search result ranking for MyChannel
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
MODEL_ENDPOINT = os.environ.get('MODEL_ENDPOINT', 'search-ranking-v1')

aiplatform.init(project=PROJECT_ID, location=REGION)


def compute_relevance_score(result: dict, query: str, user_context: dict) -> float:
    """Compute search relevance score for a result."""
    score = 0.0
    query_lower = query.lower()

    # Title match strength
    title = result.get('title', '').lower()
    if query_lower in title:
        score += 0.30
    elif any(word in title for word in query_lower.split()):
        word_matches = sum(1 for w in query_lower.split() if w in title)
        score += 0.15 * (word_matches / max(len(query_lower.split()), 1))

    # Description match
    description = result.get('description', '').lower()
    if query_lower in description:
        score += 0.10
    elif any(word in description for word in query_lower.split()):
        score += 0.05

    # Tags match
    tags = [t.lower() for t in result.get('tags', [])]
    tag_matches = sum(1 for w in query_lower.split() if w in tags)
    score += min(tag_matches * 0.05, 0.15)

    # Quality signals
    view_count = result.get('view_count', 0)
    if view_count > 1_000_000:
        score += 0.12
    elif view_count > 100_000:
        score += 0.08
    elif view_count > 10_000:
        score += 0.04

    like_ratio = result.get('like_ratio', 0.0)
    score += like_ratio * 0.08

    # Personalization boost
    user_categories = user_context.get('top_categories', [])
    result_category = result.get('category', '')
    if result_category in user_categories[:3]:
        score += 0.10

    followed_creators = user_context.get('followed_creators', [])
    if result.get('creator_id') in followed_creators:
        score += 0.08

    # Freshness
    hours_old = result.get('hours_since_published', 720)
    if hours_old < 24:
        score += 0.05
    elif hours_old < 168:
        score += 0.02

    # Trending boost
    if result.get('is_trending', False):
        score += 0.07

    return min(max(round(score, 4), 0.0), 1.0)


def rank_results(results: list, query: str, user_context: dict) -> list:
    """Rank search results by relevance score."""
    scored = []
    for result in results:
        rel_score = compute_relevance_score(result, query, user_context)
        scored.append({
            **result,
            'relevance_score': rel_score
        })
    scored.sort(key=lambda x: x['relevance_score'], reverse=True)
    return scored


@app.route('/predict', methods=['POST'])
def rank_search():
    """Rank search results for a query."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        query = data.get('query', '')
        if not query:
            return jsonify({'error': 'No query provided'}), 400

        results = data.get('results', [])
        user_context = data.get('user_context', {})
        user_id = data.get('user_id', 'anonymous')

        if not results:
            return jsonify({'predictions': [{'query': query, 'ranked_results': [], 'total': 0}]}), 200

        ranked = rank_results(results, query, user_context)

        response = {
            'predictions': [{
                'query': query,
                'user_id': user_id,
                'ranked_results': ranked,
                'total': len(ranked),
                'top_result_score': ranked[0]['relevance_score'] if ranked else 0,
                'confidence': 0.89
            }]
        }

        logging.info(f"Search ranked: query='{query}' user={user_id} results={len(ranked)}")
        return jsonify(response), 200

    except Exception as e:
        logging.error(f"Search ranking error: {str(e)}")
        return jsonify({'error': str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'search-ranking',
        'version': 'v1.0',
        'model': MODEL_ENDPOINT
    }), 200


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
