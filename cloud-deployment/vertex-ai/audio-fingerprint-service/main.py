"""
Audio Fingerprint AI Service
Advanced audio copyright detection via fingerprinting
"""
import os
import hashlib
import json
from flask import Flask, request, jsonify

app = Flask(__name__)

def generate_audio_fingerprint(audio_features: dict) -> str:
    """Generate a fingerprint from audio spectral features"""
    chroma = audio_features.get('chromaFeatures', [])
    mfcc = audio_features.get('mfccFeatures', [])
    spectral_centroid = audio_features.get('spectralCentroid', 0)
    tempo = audio_features.get('tempo', 120)

    # Create a stable fingerprint from features
    feature_string = f"{round(spectral_centroid, 0)}:{round(tempo, 0)}:{len(chroma)}:{len(mfcc)}"
    if chroma:
        feature_string += ':' + ':'.join(str(round(c, 2)) for c in chroma[:10])

    return hashlib.sha256(feature_string.encode()).hexdigest()[:32]

def match_fingerprint(query_fingerprint: str, database_fingerprints: list) -> dict:
    """Match a fingerprint against known copyright database"""
    matches = []

    for entry in database_fingerprints:
        stored_fp = entry.get('fingerprint', '')
        # Simple Hamming-like distance on hex strings
        if len(query_fingerprint) == len(stored_fp):
            differences = sum(a != b for a, b in zip(query_fingerprint, stored_fp))
            similarity = 1.0 - (differences / len(query_fingerprint))
            if similarity >= 0.85:
                matches.append({
                    'trackId': entry.get('trackId', ''),
                    'title': entry.get('title', ''),
                    'artist': entry.get('artist', ''),
                    'similarity': round(similarity, 3),
                    'copyrightHolder': entry.get('copyrightHolder', ''),
                    'licenseType': entry.get('licenseType', 'all_rights_reserved')
                })

    matches.sort(key=lambda x: x['similarity'], reverse=True)
    best_match = matches[0] if matches else None

    return {
        'fingerprint': query_fingerprint,
        'matches': matches[:5],
        'bestMatch': best_match,
        'hasCopyrightMatch': best_match is not None,
        'confidence': best_match['similarity'] if best_match else 0.0,
        'action': _get_action(best_match)
    }

def _get_action(match: dict) -> str:
    if not match:
        return 'allow'
    similarity = match.get('similarity', 0)
    license_type = match.get('licenseType', 'all_rights_reserved')
    if license_type in ['cc0', 'cc_by', 'royalty_free']:
        return 'allow_with_attribution'
    if similarity >= 0.95:
        return 'block_or_mute'
    if similarity >= 0.85:
        return 'monetization_redirect'
    return 'monitor'

@app.route('/fingerprint', methods=['POST'])
def fingerprint():
    data = request.json
    audio_features = data.get('audioFeatures', {})
    fp = generate_audio_fingerprint(audio_features)
    return jsonify({'fingerprint': fp, 'videoId': data.get('videoId', '')})

@app.route('/match', methods=['POST'])
def match():
    data = request.json
    audio_features = data.get('audioFeatures', {})
    database = data.get('database', [])
    fp = generate_audio_fingerprint(audio_features)
    result = match_fingerprint(fp, database)
    return jsonify({'videoId': data.get('videoId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'audio-fingerprint-ai'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
