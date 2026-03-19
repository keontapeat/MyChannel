"""
Mood Detection AI Service
Detect user mood from behavior to serve better content
"""
import os
import json
from flask import Flask, request, jsonify
from datetime import datetime

app = Flask(__name__)

MOOD_PROFILES = {
    'relaxed': {'genres': ['ambient', 'comedy', 'vlog', 'nature'], 'pace': 'slow', 'length': 'long'},
    'energetic': {'genres': ['workout', 'music', 'sports', 'gaming'], 'pace': 'fast', 'length': 'short'},
    'curious': {'genres': ['documentary', 'tutorial', 'science', 'tech'], 'pace': 'medium', 'length': 'medium'},
    'sad': {'genres': ['comedy', 'feel_good', 'music', 'pets'], 'pace': 'slow', 'length': 'short'},
    'focused': {'genres': ['tutorial', 'lecture', 'howto', 'coding'], 'pace': 'medium', 'length': 'long'},
    'bored': {'genres': ['trending', 'viral', 'shorts', 'challenges'], 'pace': 'fast', 'length': 'very_short'},
    'stressed': {'genres': ['asmr', 'meditation', 'nature', 'comedy'], 'pace': 'slow', 'length': 'short'},
}

def detect_mood(behavior: dict) -> dict:
    """Detect user mood from behavioral signals"""
    
    signals = {}
    
    # Time of day
    hour = datetime.now().hour
    if 6 <= hour < 9:
        signals['time_of_day'] = 'morning'
    elif 9 <= hour < 17:
        signals['time_of_day'] = 'work_hours'
    elif 17 <= hour < 21:
        signals['time_of_day'] = 'evening'
    else:
        signals['time_of_day'] = 'night'
    
    # Session behavior
    scroll_speed = behavior.get('scrollSpeed', 1.0)
    session_duration = behavior.get('sessionDuration', 0)
    skips = behavior.get('skipCount', 0)
    completions = behavior.get('completionCount', 0)
    search_queries = behavior.get('recentSearches', [])
    
    mood_scores = {mood: 0.0 for mood in MOOD_PROFILES}
    
    # Fast scrolling = bored or energetic
    if scroll_speed > 2.0:
        mood_scores['bored'] += 0.4
        mood_scores['energetic'] += 0.2
    elif scroll_speed < 0.5:
        mood_scores['relaxed'] += 0.3
        mood_scores['focused'] += 0.2
    
    # Many skips = bored or stressed
    skip_ratio = skips / max(skips + completions, 1)
    if skip_ratio > 0.6:
        mood_scores['bored'] += 0.3
        mood_scores['stressed'] += 0.2
    elif skip_ratio < 0.2:
        mood_scores['focused'] += 0.3
        mood_scores['relaxed'] += 0.2
    
    # Time signals
    if signals['time_of_day'] == 'morning':
        mood_scores['energetic'] += 0.2
        mood_scores['curious'] += 0.2
    elif signals['time_of_day'] == 'night':
        mood_scores['relaxed'] += 0.3
        mood_scores['stressed'] += 0.1
    elif signals['time_of_day'] == 'work_hours':
        mood_scores['focused'] += 0.2
        mood_scores['curious'] += 0.2
    
    # Long sessions = engaged/focused
    if session_duration > 1800:  # 30+ min
        mood_scores['relaxed'] += 0.2
        mood_scores['focused'] += 0.2
    elif session_duration < 300:  # Under 5 min
        mood_scores['bored'] += 0.2
        mood_scores['energetic'] += 0.1
    
    # Search behavior
    for query in search_queries:
        q_lower = query.lower()
        if any(w in q_lower for w in ['how to', 'tutorial', 'learn']):
            mood_scores['curious'] += 0.3
            mood_scores['focused'] += 0.2
        if any(w in q_lower for w in ['funny', 'meme', 'comedy']):
            mood_scores['bored'] += 0.2
            mood_scores['sad'] += 0.1
        if any(w in q_lower for w in ['workout', 'gym', 'sport']):
            mood_scores['energetic'] += 0.4
        if any(w in q_lower for w in ['relax', 'calm', 'sleep', 'asmr']):
            mood_scores['stressed'] += 0.3
            mood_scores['relaxed'] += 0.3
    
    # Get top mood
    top_mood = max(mood_scores, key=mood_scores.get)
    top_score = mood_scores[top_mood]
    confidence = min(top_score / 1.5, 1.0)
    
    # Sort moods by score
    sorted_moods = sorted(mood_scores.items(), key=lambda x: x[1], reverse=True)
    
    return {
        'primaryMood': top_mood,
        'confidence': round(confidence, 3),
        'moodScores': {k: round(v, 3) for k, v in sorted_moods},
        'contentProfile': MOOD_PROFILES[top_mood],
        'signals': signals,
        'recommendedGenres': MOOD_PROFILES[top_mood]['genres'],
        'recommendedPace': MOOD_PROFILES[top_mood]['pace'],
        'recommendedLength': MOOD_PROFILES[top_mood]['length']
    }

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    user_id = data.get('userId', '')
    behavior = data.get('behavior', {})
    
    result = detect_mood(behavior)
    
    return jsonify({
        'userId': user_id,
        **result
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'mood-detection-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
