"""
Music Mood AI Service
Match background music to video mood/content
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

MOOD_MUSIC_MAP = {
    'happy': {'genres': ['pop', 'upbeat', 'funk'], 'bpm_range': [100, 130], 'key': 'major'},
    'sad': {'genres': ['ambient', 'piano', 'acoustic'], 'bpm_range': [60, 90], 'key': 'minor'},
    'energetic': {'genres': ['edm', 'rock', 'hiphop'], 'bpm_range': [128, 160], 'key': 'major'},
    'relaxed': {'genres': ['lofi', 'ambient', 'jazz'], 'bpm_range': [70, 100], 'key': 'major'},
    'dramatic': {'genres': ['orchestral', 'cinematic', 'epic'], 'bpm_range': [80, 140], 'key': 'minor'},
    'funny': {'genres': ['quirky', 'cartoon', 'comedy'], 'bpm_range': [100, 140], 'key': 'major'},
    'inspirational': {'genres': ['acoustic', 'piano', 'orchestral'], 'bpm_range': [80, 110], 'key': 'major'},
    'tense': {'genres': ['thriller', 'electronic', 'dark'], 'bpm_range': [110, 150], 'key': 'minor'},
}

def recommend_music(video_data: dict) -> dict:
    title = video_data.get('title', '')
    description = video_data.get('description', '')
    category = video_data.get('category', '')
    transcript_snippet = video_data.get('transcript', '')[:500]

    prompt = f"""Analyze this video and recommend background music.

TITLE: {title}
CATEGORY: {category}
DESCRIPTION: {description[:200]}
TRANSCRIPT: {transcript_snippet}

Return JSON:
{{
  "mood": "one of: {', '.join(MOOD_MUSIC_MAP.keys())}",
  "energy": "low/medium/high",
  "recommendedGenres": ["genre1", "genre2"],
  "bpmRange": [min, max],
  "musicStyle": "brief description",
  "avoidGenres": ["genre to avoid"],
  "searchTerms": ["term1", "term2", "term3"]
}}
Return ONLY valid JSON."""

    try:
        response = model.generate_content(prompt)
        import re
        m = re.search(r'\{.*\}', response.text, re.DOTALL)
        if m:
            result = json.loads(m.group())
            mood = result.get('mood', 'relaxed')
            if mood in MOOD_MUSIC_MAP:
                result['moodProfile'] = MOOD_MUSIC_MAP[mood]
            return result
    except Exception as e:
        print(f"Music mood error: {e}")

    mood = 'relaxed'
    return {
        'mood': mood,
        'energy': 'medium',
        'recommendedGenres': MOOD_MUSIC_MAP[mood]['genres'],
        'bpmRange': MOOD_MUSIC_MAP[mood]['bpm_range'],
        'moodProfile': MOOD_MUSIC_MAP[mood],
        'searchTerms': [f'{mood} background music', 'royalty free music']
    }

@app.route('/recommend', methods=['POST'])
def recommend():
    data = request.json
    result = recommend_music(data.get('videoData', {}))
    return jsonify({'videoId': data.get('videoId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'music-mood-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
