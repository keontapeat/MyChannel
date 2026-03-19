"""
Discovery Mode AI Service
Know when user wants to explore new content vs comfort zone
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def detect_discovery_mode(user_signals: dict) -> dict:
    watch_history = user_signals.get('watchHistory', [])
    search_history = user_signals.get('searchHistory', [])
    explicit_explore = user_signals.get('clickedExplore', False)
    browse_pattern = user_signals.get('browsePattern', 'scroll')  # scroll/tap/search
    skip_rate = user_signals.get('recentSkipRate', 0.3)
    category_diversity_7d = user_signals.get('categoryDiversity7d', 0.3)
    followed_new_creators_7d = user_signals.get('followedNewCreators7d', 0)
    session_scroll_depth = user_signals.get('sessionScrollDepth', 1.0)

    discovery_score = 0.0
    signals = {}

    # Explicit explore action
    if explicit_explore:
        discovery_score += 0.5
        signals['explicit_explore'] = True

    # High skip rate = not finding what they want = discovery mode
    if skip_rate > 0.6:
        discovery_score += 0.25
        signals['high_skip_rate'] = True

    # Low category diversity = comfort zone (low discovery intent)
    # High diversity = already exploring (moderate discovery intent)
    if category_diversity_7d < 0.2:
        discovery_score += 0.15  # Stuck in comfort zone, show new content
        signals['low_diversity'] = True

    # Recently followed new creators = discovery mindset
    if followed_new_creators_7d >= 2:
        discovery_score += 0.2
        signals['following_new_creators'] = True

    # Deep scroll without clicking = browsing/exploring
    if session_scroll_depth > 3.0 and browse_pattern == 'scroll':
        discovery_score += 0.15
        signals['deep_browse'] = True

    # Search for broad/vague terms
    broad_searches = [s for s in search_history[-5:] if len(s.split()) <= 2]
    if len(broad_searches) >= 2:
        discovery_score += 0.15
        signals['broad_searches'] = True

    discovery_score = min(round(discovery_score, 3), 1.0)
    in_discovery_mode = discovery_score >= 0.4

    feed_config = {}
    if in_discovery_mode:
        feed_config = {
            'newCreatorBoost': 0.4,
            'diversityInjection': 0.3,
            'trendingNewContent': 0.2,
            'familiar': 0.1,
            'showExplorePrompt': True,
            'recommendationStrategy': 'serendipity'
        }
    else:
        feed_config = {
            'newCreatorBoost': 0.1,
            'diversityInjection': 0.1,
            'familiar': 0.7,
            'trending': 0.1,
            'showExplorePrompt': False,
            'recommendationStrategy': 'familiar'
        }

    return {
        'inDiscoveryMode': in_discovery_mode,
        'discoveryScore': discovery_score,
        'signals': signals,
        'feedConfiguration': feed_config,
        'explorationPrompt': 'Ready to discover something new? 🔍' if in_discovery_mode else None
    }

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_discovery_mode(data.get('userSignals', {}))
    return jsonify({'userId': data.get('userId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'discovery-mode-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
