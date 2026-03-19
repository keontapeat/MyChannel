"""
Synthetic Media Detection AI Service
Detect ALL AI-generated content (deepfakes, AI images, AI voice, AI text)
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

DETECTION_MODELS = {
    'deepfake_video': 'Facial inconsistency + temporal analysis',
    'ai_generated_image': 'GAN artifacts + metadata analysis',
    'ai_voice': 'Spectral analysis + prosody patterns',
    'ai_text': 'Perplexity + burstiness analysis',
    'face_swap': 'Boundary detection + lighting inconsistency'
}

def detect_synthetic_media(content: dict) -> dict:
    """Comprehensive synthetic media detection"""
    
    results = {}
    overall_confidence = 0.0
    detection_count = 0
    
    content_type = content.get('type', 'unknown')
    
    # Video analysis
    if content_type in ['video', 'short', 'live']:
        video_signals = content.get('videoSignals', {})
        results['deepfake'] = _analyze_deepfake_signals(video_signals)
        results['faceSwap'] = _analyze_face_swap(video_signals)
        overall_confidence += results['deepfake']['confidence']
        overall_confidence += results['faceSwap']['confidence']
        detection_count += 2
    
    # Image analysis
    if content_type in ['image', 'thumbnail', 'video']:
        image_signals = content.get('imageSignals', {})
        results['aiGeneratedImage'] = _analyze_ai_image(image_signals)
        overall_confidence += results['aiGeneratedImage']['confidence']
        detection_count += 1
    
    # Audio analysis
    audio_signals = content.get('audioSignals', {})
    if audio_signals:
        results['aiVoice'] = _analyze_ai_voice(audio_signals)
        overall_confidence += results['aiVoice']['confidence']
        detection_count += 1
    
    # Text analysis
    text = content.get('transcript', '') or content.get('description', '')
    if text:
        results['aiText'] = _analyze_ai_text(text)
        overall_confidence += results['aiText']['confidence']
        detection_count += 1
    
    avg_confidence = overall_confidence / max(detection_count, 1)
    
    # Any synthetic detection
    is_synthetic = any(
        r.get('isSynthetic', False)
        for r in results.values()
    )
    
    # Build detection summary
    detected_types = [
        k for k, v in results.items()
        if v.get('isSynthetic', False)
    ]
    
    return {
        'isSynthetic': is_synthetic,
        'syntheticTypes': detected_types,
        'overallConfidence': round(avg_confidence, 3),
        'detectionResults': results,
        'requiresDisclosure': is_synthetic and avg_confidence > 0.7,
        'action': _get_action(is_synthetic, avg_confidence),
        'explanation': _get_explanation(detected_types)
    }

def _analyze_deepfake_signals(signals: dict) -> dict:
    """Analyze deepfake indicators in video"""
    indicators = 0
    total = 0
    
    checks = {
        'facialInconsistency': signals.get('facialInconsistencyScore', 0),
        'eyeBlinkRate': signals.get('abnormalBlinkRate', False),
        'lightingMismatch': signals.get('lightingMismatchScore', 0),
        'compressionArtifacts': signals.get('compressionArtifactScore', 0),
        'temporalInconsistency': signals.get('temporalInconsistencyScore', 0)
    }
    
    for check, value in checks.items():
        total += 1
        if isinstance(value, bool) and value:
            indicators += 1
        elif isinstance(value, (int, float)) and value > 0.5:
            indicators += 1
    
    confidence = indicators / max(total, 1)
    
    return {
        'isSynthetic': confidence > 0.6,
        'confidence': round(confidence, 3),
        'checks': checks,
        'method': 'facial_temporal_analysis'
    }

def _analyze_face_swap(signals: dict) -> dict:
    boundary_score = signals.get('faceBoundaryScore', 0)
    texture_score = signals.get('textureInconsistencyScore', 0)
    confidence = (boundary_score + texture_score) / 2
    
    return {
        'isSynthetic': confidence > 0.6,
        'confidence': round(confidence, 3),
        'method': 'boundary_texture_analysis'
    }

def _analyze_ai_image(signals: dict) -> dict:
    gan_score = signals.get('ganArtifactScore', 0)
    metadata_missing = signals.get('missingCameraMetadata', False)
    noise_pattern = signals.get('unnaturalNoisePattern', False)
    
    confidence = gan_score
    if metadata_missing: confidence += 0.2
    if noise_pattern: confidence += 0.15
    confidence = min(1.0, confidence)
    
    return {
        'isSynthetic': confidence > 0.6,
        'confidence': round(confidence, 3),
        'method': 'gan_artifact_metadata_analysis'
    }

def _analyze_ai_voice(signals: dict) -> dict:
    spectral_anomaly = signals.get('spectralAnomalyScore', 0)
    prosody_score = signals.get('unnaturalProsodyScore', 0)
    confidence = (spectral_anomaly + prosody_score) / 2
    
    return {
        'isSynthetic': confidence > 0.6,
        'confidence': round(confidence, 3),
        'method': 'spectral_prosody_analysis'
    }

def _analyze_ai_text(text: str) -> dict:
    """Use Gemini to detect AI-generated text"""
    prompt = f"""Is this text AI-generated? Analyze for:
- Unusually consistent sentence structure
- Lack of personal anecdotes
- Generic phrasing
- Unnaturally perfect grammar

TEXT: {text[:500]}

Return JSON: {{"isAiGenerated": bool, "confidence": 0-1, "indicators": []}}
Return ONLY valid JSON."""
    
    try:
        response = model.generate_content(prompt)
        import re
        json_match = re.search(r'\{.*\}', response.text, re.DOTALL)
        if json_match:
            result = json.loads(json_match.group())
            return {
                'isSynthetic': result.get('isAiGenerated', False),
                'confidence': result.get('confidence', 0.5),
                'indicators': result.get('indicators', []),
                'method': 'llm_perplexity_analysis'
            }
    except:
        pass
    
    return {'isSynthetic': False, 'confidence': 0.3, 'indicators': [], 'method': 'llm_analysis'}

def _get_action(is_synthetic: bool, confidence: float) -> str:
    if not is_synthetic:
        return 'allow'
    if confidence > 0.9:
        return 'remove_and_notify'
    if confidence > 0.7:
        return 'require_disclosure_label'
    return 'flag_for_review'

def _get_explanation(detected_types: list) -> str:
    if not detected_types:
        return 'No synthetic media detected'
    return f'Synthetic media detected: {", ".join(detected_types)}'

@app.route('/detect', methods=['POST'])
def detect():
    data = request.json
    video_id = data.get('videoId', '')
    content = data.get('content', {})
    
    result = detect_synthetic_media(content)
    
    return jsonify({
        'videoId': video_id,
        **result
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'synthetic-media-detection-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
