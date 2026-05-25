"""
Binge Watch Predictor Service
Predict binge sessions to maximize watch time (Netflix's secret weapon)
"""
import os
import json
import math
from flask import Flask, request, jsonify

app = Flask(__name__)

def predict_binge(user_history: dict, current_session: dict) -> dict:
    """Predict probability and duration of binge watching session"""
    
    # Historical binge patterns
    avg_session_duration = user_history.get('avgSessionDuration', 600)
    max_session_duration = user_history.get('maxSessionDuration', 3600)
    binge_frequency = user_history.get('bingeFrequency', 0.2)  # 0-1
    preferred_binge_genres = user_history.get('bingeGenres', [])
    
    # Current session signals
    current_duration = current_session.get('duration', 0)
    current_genre = current_session.get('currentGenre', '')
    videos_watched = current_session.get('videosWatched', 1)
    time_of_day = current_session.get('timeOfDay', 12)
    day_of_week = current_session.get('dayOfWeek', 0)
    completion_rate = current_session.get('completionRate', 0.8)
    
    # Feature engineering
    features = {}
    
    # Session momentum (already watching a lot = likely to continue)
    features['session_momentum'] = min(current_duration / 3600, 1.0)
    
    # Genre match (watching favorite binge genre)
    features['genre_match'] = 1.0 if current_genre in preferred_binge_genres else 0.3
    
    # Videos per hour (more = more engaged)
    hours_in_session = max(current_duration / 3600, 0.1)
    videos_per_hour = videos_watched / hours_in_session
    features['engagement_rate'] = min(videos_per_hour / 10, 1.0)
    
    # Time window (nights/weekends = higher binge probability)
    is_night = time_of_day >= 20 or time_of_day <= 2
    is_weekend = day_of_week in [5, 6]  # Sat/Sun
    features['time_window'] = 0.8 if is_night else (0.6 if is_weekend else 0.3)
    
    # Historical binge tendency
    features['historical_tendency'] = binge_frequency
    
    # Completion rate (finishing videos = engaged)
    features['completion_rate'] = completion_rate
    
    # Calculate binge probability
    weights = {
        'session_momentum': 0.25,
        'genre_match': 0.15,
        'engagement_rate': 0.20,
        'time_window': 0.15,
        'historical_tendency': 0.15,
        'completion_rate': 0.10
    }
    
    binge_prob = sum(features[k] * weights[k] for k in features)
    binge_prob = round(min(binge_prob, 1.0), 3)
    
    # Predict session duration
    base_duration = avg_session_duration
    if binge_prob > 0.7:
        predicted_duration = min(base_duration * 3, max_session_duration)
    elif binge_prob > 0.5:
        predicted_duration = min(base_duration * 1.5, max_session_duration)
    else:
        predicted_duration = base_duration
    
    remaining_duration = max(0, predicted_duration - current_duration)
    
    # Optimal next video strategy
    next_video_strategy = _get_next_video_strategy(binge_prob, current_genre)
    
    return {
        'bingeProbability': binge_prob,
        'isBinging': binge_prob > 0.6,
        'predictedTotalDuration': round(predicted_duration),
        'predictedRemainingDuration': round(remaining_duration),
        'features': {k: round(v, 3) for k, v in features.items()},
        'nextVideoStrategy': next_video_strategy,
        'autoplayDelay': 3 if binge_prob > 0.7 else 5,
        'showContinueWatching': binge_prob > 0.5
    }

def _get_next_video_strategy(binge_prob: float, genre: str) -> dict:
    """Determine optimal next video to show"""
    if binge_prob > 0.7:
        return {
            'strategy': 'series_continuation',
            'description': 'Show next episode or part of same series',
            'autoplay': True,
            'delay': 3
        }
    elif binge_prob > 0.5:
        return {
            'strategy': 'same_creator',
            'description': 'Show another video from same creator',
            'autoplay': True,
            'delay': 5
        }
    else:
        return {
            'strategy': 'related_content',
            'description': 'Show related content',
            'autoplay': False,
            'delay': 10
        }

@app.route('/predict', methods=['POST'])
def predict():
    data = request.json
    user_id = data.get('userId', '')
    user_history = data.get('userHistory', {})
    current_session = data.get('currentSession', {})
    
    result = predict_binge(user_history, current_session)
    
    return jsonify({
        'userId': user_id,
        **result
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'binge-watch-predictor'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
