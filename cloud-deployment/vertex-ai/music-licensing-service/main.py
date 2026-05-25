"""
Music Licensing AI Service
Solve #1 creator pain point - find licensed alternatives to flagged music
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

# Free/licensed music sources
LICENSED_SOURCES = {
    'youtube_audio_library': {'url': 'https://studio.youtube.com/channel/UCxx/music', 'cost': 'free', 'attribution': False},
    'pixabay': {'url': 'https://pixabay.com/music/', 'cost': 'free', 'attribution': False},
    'freesound': {'url': 'https://freesound.org', 'cost': 'free', 'attribution': True},
    'epidemic_sound': {'url': 'https://www.epidemicsound.com', 'cost': 'subscription', 'attribution': False},
    'artlist': {'url': 'https://artlist.io', 'cost': 'subscription', 'attribution': False},
    'soundstripe': {'url': 'https://www.soundstripe.com', 'cost': 'subscription', 'attribution': False},
    'musicbed': {'url': 'https://www.musicbed.com', 'cost': 'subscription', 'attribution': False},
    'pond5': {'url': 'https://www.pond5.com/royalty-free-music', 'cost': 'per_track', 'attribution': False},
    'ccmixter': {'url': 'http://ccmixter.org', 'cost': 'free', 'attribution': True},
    'incompetech': {'url': 'https://incompetech.com', 'cost': 'free', 'attribution': True},
}

def find_licensed_alternatives(flagged_song: dict) -> dict:
    """Find licensed alternatives for a copyright-flagged song"""
    
    song_title = flagged_song.get('title', '')
    artist = flagged_song.get('artist', '')
    genre = flagged_song.get('genre', '')
    mood = flagged_song.get('mood', '')
    bpm = flagged_song.get('bpm', 120)
    
    # Use Gemini to find matching licensed tracks
    prompt = f"""A creator's video was flagged for using: "{song_title}" by {artist}
Genre: {genre}, Mood: {mood}, BPM: {bpm}

Suggest 5 royalty-free alternatives that sound similar.
Include songs from: Pixabay, YouTube Audio Library, ccMixter, or Incompetech.

Return JSON with array of alternatives, each having:
- "title": song name
- "artist": artist name  
- "source": where to find it (one of the licensed sources)
- "similarity": 0-1 similarity score
- "genre": genre
- "mood": mood description
- "bpm": approximate BPM
- "licenseType": "cc0", "cc_by", "royalty_free"

Return ONLY valid JSON array."""

    alternatives = []
    try:
        response = model.generate_content(prompt)
        import re
        json_match = re.search(r'\[.*?\]', response.text, re.DOTALL)
        if json_match:
            alternatives = json.loads(json_match.group())
    except Exception as e:
        print(f"AI suggestion error: {e}")
    
    # Add source metadata
    for alt in alternatives:
        source_key = alt.get('source', '').lower().replace(' ', '_')
        if source_key in LICENSED_SOURCES:
            alt['sourceInfo'] = LICENSED_SOURCES[source_key]
    
    return {
        'flaggedSong': flagged_song,
        'alternatives': alternatives,
        'licenseGuidance': _get_license_guidance(flagged_song),
        'contentIdInfo': _get_content_id_info(song_title, artist),
        'sources': LICENSED_SOURCES
    }

def check_music_rights(song_title: str, artist: str) -> dict:
    """Check if a song is likely to trigger Content ID"""
    
    # Known major label artists (high risk)
    major_label_indicators = [
        'Universal Music', 'Sony Music', 'Warner Music', 'BMG', 'EMI'
    ]
    
    # This would integrate with a music rights database in production
    # For now, provide guidance
    
    risk_level = 'unknown'
    guidance = []
    
    prompt = f"""Is the song "{song_title}" by {artist} likely to be subject to copyright Content ID claims on video platforms?

Return JSON with:
- "riskLevel": "low", "medium", "high", or "unknown"
- "reasoning": brief explanation
- "safeToUse": boolean
- "alternativeAction": what creator should do

Return ONLY valid JSON."""

    try:
        response = model.generate_content(prompt)
        import re
        json_match = re.search(r'\{.*\}', response.text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
    except:
        pass
    
    return {
        'riskLevel': 'unknown',
        'reasoning': 'Unable to determine rights status',
        'safeToUse': False,
        'alternativeAction': 'Use royalty-free music to be safe'
    }

def _get_license_guidance(song: dict) -> list:
    return [
        'Replace with royalty-free music to avoid demonetization',
        'Check YouTube Audio Library for free alternatives',
        'Consider subscribing to Epidemic Sound for unlimited access',
        'For live music, contact the rights holder for a sync license',
        'Creative Commons music from ccMixter is free with attribution'
    ]

def _get_content_id_info(title: str, artist: str) -> dict:
    return {
        'likelyClaimed': True,
        'claimType': 'monetization_redirect',
        'resolution': 'Replace or mute the flagged segment',
        'appealOption': True
    }

@app.route('/alternatives', methods=['POST'])
def get_alternatives():
    data = request.json
    video_id = data.get('videoId', '')
    flagged_song = data.get('flaggedSong', {})
    
    result = find_licensed_alternatives(flagged_song)
    
    return jsonify({
        'videoId': video_id,
        **result
    })

@app.route('/check', methods=['POST'])
def check_rights():
    data = request.json
    title = data.get('title', '')
    artist = data.get('artist', '')
    
    result = check_music_rights(title, artist)
    return jsonify(result)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'music-licensing-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
