"""
Local Trending AI Service
Per-country trending feeds - what's viral in YOUR country
"""
import os
import json
from flask import Flask, request, jsonify
from datetime import datetime, timedelta
from collections import defaultdict

app = Flask(__name__)

# Regional weight multipliers
REGIONAL_FACTORS = {
    'language_weight': 2.5,    # Same language content boosted
    'local_creator_weight': 2.0,  # Local creators boosted
    'local_event_weight': 3.0,    # Local events/news boosted
    'global_viral_weight': 0.7    # Global trends slightly dampened
}

def calculate_local_trending_score(video: dict, country: str, language: str) -> float:
    """Score video for local trending in specific country/language"""
    
    base_score = video.get('trendingScore', 0.5)
    
    # Language match
    video_language = video.get('language', 'en')
    if video_language == language:
        base_score *= REGIONAL_FACTORS['language_weight']
    
    # Local creator
    creator_country = video.get('creatorCountry', '')
    if creator_country == country:
        base_score *= REGIONAL_FACTORS['local_creator_weight']
    
    # Local tags
    tags = video.get('tags', [])
    local_relevant = any(country.lower() in tag.lower() or language.lower() in tag.lower() for tag in tags)
    if local_relevant:
        base_score *= 1.5
    
    # Velocity in this region
    regional_velocity = video.get(f'velocity_{country}', video.get('velocity', 1.0))
    base_score *= regional_velocity
    
    # Recent boost (newer = more trending)
    hours_old = video.get('hoursOld', 24)
    if hours_old < 6:
        base_score *= 1.5
    elif hours_old < 24:
        base_score *= 1.2
    elif hours_old > 72:
        base_score *= 0.7
    
    return round(base_score, 4)

def generate_local_trending_feed(country: str, language: str, videos: list, limit: int = 50) -> dict:
    """Generate a trending feed personalized to a specific country"""
    
    scored_videos = []
    for video in videos:
        local_score = calculate_local_trending_score(video, country, language)
        scored_videos.append({
            **video,
            'localTrendingScore': local_score,
            'country': country,
            'language': language
        })
    
    # Sort by local trending score
    scored_videos.sort(key=lambda x: x['localTrendingScore'], reverse=True)
    
    # Get top videos
    top_videos = scored_videos[:limit]
    
    # Categorize
    local_content = [v for v in top_videos if v.get('creatorCountry') == country]
    global_viral = [v for v in top_videos if v.get('creatorCountry') != country]
    
    # Trending topics for this region
    topics = _extract_trending_topics(top_videos[:20])
    
    return {
        'country': country,
        'language': language,
        'trending': top_videos,
        'localContentCount': len(local_content),
        'globalViralCount': len(global_viral),
        'trendingTopics': topics,
        'generatedAt': datetime.utcnow().isoformat()
    }

def _extract_trending_topics(videos: list) -> list:
    """Extract trending topics from video tags"""
    tag_counts = defaultdict(int)
    
    for video in videos:
        for tag in video.get('tags', []):
            tag_counts[tag.lower()] += 1
    
    # Sort by frequency
    sorted_tags = sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)
    
    return [
        {'topic': tag, 'videoCount': count}
        for tag, count in sorted_tags[:10]
    ]

# Country to language mapping
COUNTRY_LANGUAGES = {
    'US': 'en', 'GB': 'en', 'CA': 'en', 'AU': 'en',
    'MX': 'es', 'ES': 'es', 'AR': 'es', 'CO': 'es',
    'BR': 'pt', 'PT': 'pt',
    'FR': 'fr', 'BE': 'fr',
    'DE': 'de', 'AT': 'de', 'CH': 'de',
    'JP': 'ja', 'KR': 'ko', 'CN': 'zh',
    'IN': 'hi', 'SA': 'ar', 'AE': 'ar',
    'RU': 'ru', 'NG': 'en', 'GH': 'en',
    'ID': 'id', 'PH': 'tl', 'TH': 'th', 'VN': 'vi'
}

@app.route('/trending', methods=['POST'])
def get_local_trending():
    data = request.json
    country = data.get('country', 'US').upper()
    language = data.get('language', COUNTRY_LANGUAGES.get(country, 'en'))
    videos = data.get('videos', [])
    limit = data.get('limit', 50)
    
    result = generate_local_trending_feed(country, language, videos, limit)
    
    return jsonify(result)

@app.route('/countries', methods=['GET'])
def get_supported_countries():
    return jsonify({
        'countries': list(COUNTRY_LANGUAGES.keys()),
        'count': len(COUNTRY_LANGUAGES)
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'local-trending-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
