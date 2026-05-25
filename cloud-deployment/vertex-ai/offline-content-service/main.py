"""
Offline Content AI Service
Predict what to cache for offline viewing
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def predict_offline_content(user_profile: dict, device_info: dict) -> dict:
    watch_history = user_profile.get('watchHistory', [])
    subscribed_creators = user_profile.get('subscribedCreators', [])
    typical_offline_hours = user_profile.get('typicalOfflineHours', [])
    storage_available_mb = device_info.get('storageAvailableMB', 2000)
    wifi_available = device_info.get('wifiAvailable', True)

    # Only suggest downloads on WiFi
    if not wifi_available:
        return {'shouldDownload': False, 'reason': 'No WiFi - wait for connection', 'recommendations': []}

    # Calculate download budget
    avg_video_size_mb = 200  # ~200MB per video at 720p
    max_videos = min(storage_available_mb // avg_video_size_mb, 10)

    if max_videos == 0:
        return {'shouldDownload': False, 'reason': 'Insufficient storage', 'recommendations': []}

    recommendations = []
    priority_score = {}

    # Score based on creator subscriptions
    for creator_id in subscribed_creators[:10]:
        priority_score[creator_id] = priority_score.get(creator_id, 0) + 0.4

    # Score based on watch history patterns
    genre_counts = {}
    for video in watch_history[-30:]:
        genre = video.get('category', '')
        if genre:
            genre_counts[genre] = genre_counts.get(genre, 0) + 1

    top_genres = sorted(genre_counts.items(), key=lambda x: x[1], reverse=True)[:3]

    recommendations = [
        {
            'type': 'new_from_subscriptions',
            'description': 'Latest from your subscribed creators',
            'videoCount': min(3, max_videos),
            'estimatedSizeMB': min(3, max_videos) * avg_video_size_mb,
            'priority': 'high'
        },
        {
            'type': 'continue_watching',
            'description': 'Videos you started but did not finish',
            'videoCount': min(2, max_videos - 3),
            'estimatedSizeMB': min(2, max_videos - 3) * avg_video_size_mb,
            'priority': 'high'
        },
        {
            'type': 'recommended_for_you',
            'description': f'Based on your love of {top_genres[0][0] if top_genres else "trending videos"}',
            'videoCount': min(2, max_videos - 5),
            'estimatedSizeMB': min(2, max_videos - 5) * avg_video_size_mb,
            'priority': 'medium'
        }
    ]

    total_size = sum(r['estimatedSizeMB'] for r in recommendations)

    return {
        'shouldDownload': True,
        'maxVideos': max_videos,
        'storageAvailableMB': storage_available_mb,
        'estimatedTotalSizeMB': total_size,
        'recommendations': recommendations,
        'topGenres': [g[0] for g in top_genres],
        'downloadWindow': 'Now (on WiFi)'
    }

@app.route('/predict', methods=['POST'])
def predict():
    data = request.json
    result = predict_offline_content(
        data.get('userProfile', {}),
        data.get('deviceInfo', {})
    )
    return jsonify({'userId': data.get('userId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'offline-content-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
