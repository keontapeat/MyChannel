"""
Voice Clone Detector AI Service
Detect unauthorized voice cloning/synthesis
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def detect_voice_clone(audio_signals: dict) -> dict:
    """Detect voice cloning from audio spectral features"""

    # Spectral indicators of TTS/voice cloning
    spectral_flatness = audio_signals.get('spectralFlatness', 0)
    prosody_naturalness = audio_signals.get('prosodyNaturalnessScore', 1.0)
    breathing_patterns = audio_signals.get('hasNaturalBreathing', True)
    vocal_fry = audio_signals.get('hasVocalFry', True)
    formant_stability = audio_signals.get('formantStabilityScore', 0.5)
    pitch_variance = audio_signals.get('pitchVariance', 0.5)
    silence_distribution = audio_signals.get('naturalSilenceDistribution', True)

    risk_score = 0.0
    indicators = []

    # TTS/cloned voice tends to be too "perfect"
    if prosody_naturalness > 0.95:
        risk_score += 0.25
        indicators.append('Unnaturally perfect prosody')

    if not breathing_patterns:
        risk_score += 0.20
        indicators.append('No natural breathing detected')

    if not vocal_fry:
        risk_score += 0.10
        indicators.append('No vocal fry - may be synthetic')

    if formant_stability > 0.95:
        risk_score += 0.20
        indicators.append('Formants too stable - likely synthetic')

    if pitch_variance < 0.05:
        risk_score += 0.15
        indicators.append('Unnatural pitch uniformity')

    if spectral_flatness > 0.8:
        risk_score += 0.10
        indicators.append('High spectral flatness - TTS indicator')

    if not silence_distribution:
        risk_score += 0.10
        indicators.append('Unnatural silence distribution')

    risk_score = min(round(risk_score, 3), 1.0)
    is_cloned = risk_score >= 0.5

    return {
        'isVoiceClone': is_cloned,
        'confidence': risk_score,
        'indicators': indicators,
        'action': 'add_disclosure_label' if is_cloned and risk_score < 0.8 else 'remove_and_review' if is_cloned else 'allow',
        'requiresDisclosure': is_cloned
    }

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    result = detect_voice_clone(data.get('audioSignals', {}))
    return jsonify({'videoId': data.get('videoId', ''), **result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'voice-clone-detector'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
