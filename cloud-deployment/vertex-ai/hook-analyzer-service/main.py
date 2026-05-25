"""
Hook Analyzer AI Service
Analyze first 30 seconds - the most critical retention window
"""
import os
import json
from flask import Flask, request, jsonify
import google.generativeai as genai

app = Flask(__name__)
genai.configure(api_key=os.environ.get('GEMINI_API_KEY', ''))
model = genai.GenerativeModel('gemini-1.5-flash')

HOOK_TYPES = {
    'question': 'Opens with a compelling question',
    'bold_claim': 'Makes a surprising or bold statement',
    'story': 'Starts with a personal story',
    'preview': 'Shows what will be revealed',
    'challenge': 'Presents a challenge or problem',
    'statistic': 'Opens with shocking statistic',
    'controversy': 'Takes a controversial stance',
    'weak': 'Weak hook - no clear strategy'
}

def analyze_hook(transcript: str, retention_data: list, duration: int) -> dict:
    """Analyze the first 30 seconds for hook effectiveness"""
    
    # Get first 30 seconds of transcript
    words = transcript.split()
    words_per_second = len(words) / max(duration, 1)
    hook_word_count = int(words_per_second * 30)
    hook_text = ' '.join(words[:max(hook_word_count, 50)])
    
    # Get retention at 30 seconds
    retention_30s = _get_retention_at(retention_data, 30)
    retention_60s = _get_retention_at(retention_data, 60)
    
    # Analyze with Gemini
    prompt = f"""Analyze this video hook (first 30 seconds) and rate its effectiveness.

HOOK TEXT: {hook_text}

RETENTION DATA:
- Viewers at 30s: {retention_30s:.1%}
- Viewers at 60s: {retention_60s:.1%}

Analyze and return JSON with:
1. "hookType" - one of: {', '.join(HOOK_TYPES.keys())}
2. "hookScore" - 0-100 effectiveness score
3. "strengths" - array of what works well
4. "weaknesses" - array of what needs improvement
5. "suggestions" - array of 3 specific improvements
6. "benchmark" - how this compares to top creators (percentile 0-100)
7. "predictedRetention30s" - predicted % of viewers still watching at 30s (0-1)
8. "verdict" - one sentence verdict

Return ONLY valid JSON."""

    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        import re
        json_match = re.search(r'\{.*\}', text, re.DOTALL)
        if json_match:
            result = json.loads(json_match.group())
            result['actualRetention30s'] = retention_30s
            result['actualRetention60s'] = retention_60s
            return result
    except Exception as e:
        print(f"Error analyzing hook: {e}")
    
    return {
        'hookType': 'unknown',
        'hookScore': 50,
        'strengths': [],
        'weaknesses': ['Could not analyze hook'],
        'suggestions': ['Add a compelling question', 'Show the value upfront', 'Create curiosity gap'],
        'benchmark': 50,
        'predictedRetention30s': 0.5,
        'actualRetention30s': retention_30s,
        'actualRetention60s': retention_60s,
        'verdict': 'Hook needs improvement.'
    }

def _get_retention_at(retention_data: list, seconds: int) -> float:
    """Get retention percentage at specific second"""
    if not retention_data:
        return 0.7  # Default assumption
    
    for point in retention_data:
        if abs(point.get('time', 0) - seconds) < 5:
            return point.get('value', 0.7)
    
    return 0.7

def generate_hook_rewrites(hook_text: str, hook_type: str) -> list:
    """Generate 3 alternative hook rewrites"""
    
    prompt = f"""Rewrite this video hook 3 different ways to maximize viewer retention.

ORIGINAL HOOK: {hook_text[:500]}
CURRENT TYPE: {hook_type}

Generate 3 rewrites using different hook strategies:
1. Question-based hook
2. Bold claim hook  
3. Story-based hook

Return JSON array of 3 strings, each under 100 words. Return ONLY valid JSON array."""
    
    try:
        response = model.generate_content(prompt)
        text = response.text.strip()
        import re
        json_match = re.search(r'\[.*?\]', text, re.DOTALL)
        if json_match:
            return json.loads(json_match.group())
    except:
        pass
    
    return []

@app.route('/analyze', methods=['POST'])
def analyze():
    data = request.json
    video_id = data.get('videoId', '')
    transcript = data.get('transcript', '')
    retention_data = data.get('retentionData', [])
    duration = data.get('duration', 600)
    
    if not transcript:
        return jsonify({'error': 'transcript required'}), 400
    
    analysis = analyze_hook(transcript, retention_data, duration)
    
    # Generate rewrites if score is low
    rewrites = []
    if analysis.get('hookScore', 100) < 70:
        words = transcript.split()
        hook_text = ' '.join(words[:50])
        rewrites = generate_hook_rewrites(hook_text, analysis.get('hookType', 'weak'))
    
    return jsonify({
        'videoId': video_id,
        **analysis,
        'hookRewrites': rewrites,
        'hookTypeDescription': HOOK_TYPES.get(analysis.get('hookType', 'weak'), '')
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'hook-analyzer-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
